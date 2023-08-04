import std/[sequtils, tables, json, hashes]
import std/[typetraits, options, unicode, strformat]
import pkg/[variant, chroma, cssgrid, windy]
import std/asyncdispatch

import cdecl/atoms
import ./[commonutils, inputs]

export sequtils, strformat, tables, hashes
export variant
# export unicode
export commonutils
export cssgrid
export atoms
export inputs
export trigger, AsyncEvent

import pretty

when defined(js):
  import dom2, html/ajax
else:
  import typography, asyncfutures

const
  clearColor* = color(0, 0, 0, 0)
  whiteColor* = color(1, 1, 1, 1)
  blackColor* = color(0, 0, 0, 1)

const
  DataDirPath* {.strdefine.} = "data"

var
  # UI Scale
  uiScale*: float32 = 1.0
  autoUiScale*: bool = true
  requestedFrame*: int

  windowTitle*, windowUrl*: string

  setWindowTitle*: proc (title: string)

  fullscreen* = false
  windowLogicalSize*: Vec2 ## Screen size in logical coordinates.
  windowSize*: Vec2    ## Screen coordinates
  # windowFrame*: Vec2   ## Pixel coordinates
  pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels
  pixelScale*: float32 ## Pixel multiplier user wants on the UI

  mouse* = Mouse()
  keyboard* = Keyboard()

  uiEvent*: AsyncEvent
  dataDir*: string = DataDirPath


type
  NodeUID* = int64

type
  All* = distinct object
  # Events* = GenericEvents[void]
  Events*[T] = object
    data*: TableRef[TypeId, Variant]

type
  FidgetConstraint* = enum
    cMin
    cMax
    cScale
    cStretch
    cCenter

  HAlign* = enum
    hLeft
    hCenter
    hRight

  VAlign* = enum
    vTop
    vCenter
    vBottom

  TextAutoResize* = enum
    ## Should text element resize and how.
    tsNone
    tsWidthAndHeight
    tsHeight

  TextStyle* = object
    ## Holder for text styles.
    fontFamily*: string
    fontSize*: UICoord
    fontWeight*: UICoord
    lineHeight*: UICoord
    textAlignHorizontal*: HAlign
    textAlignVertical*: VAlign
    autoResize*: TextAutoResize
    textPadding*: int

  BorderStyle* = object
    ## What kind of border.
    color*: Color
    width*: float32

  LayoutAlign* = enum
    ## Applicable only inside auto-layout frames.
    laMin
    laCenter
    laMax
    laStretch
    laIgnore

  LayoutMode* = enum
    ## The auto-layout mode on a frame.
    lmNone
    lmVertical
    lmHorizontal
    lmGrid

  CounterAxisSizingMode* = enum
    ## How to deal with the opposite side of an auto-layout frame.
    csAuto
    csFixed

  ShadowStyle* = enum
    ## Supports drop and inner shadows.
    DropShadow
    InnerShadow

  ZLevel* = enum
    ## The z-index for widget interactions
    ZLevelBottom
    ZLevelLower
    ZLevelDefault
    ZLevelRaised
    ZLevelOverlay

  Shadow* = object
    kind*: ShadowStyle
    blur*: UICoord
    x*: UICoord
    y*: UICoord
    color*: Color

  Stroke* = object
    weight*: float32 # not uicoord?
    color*: Color

  NodeKind* = enum
    ## Different types of nodes.
    nkRoot
    nkFrame
    nkText
    nkRectangle
    nkDrawable
    nkScrollBar
    nkImage

  Attributes* = enum
    clipContent
    disableRender
    scrollpane

  ImageStyle* = object
    name*: string
    color*: Color

  Node* = ref object
    uid*: NodeUID
    nodes*: seq[Node]
    nIndex*: int
    diffIndex*: int

    box*: Box
    orgBox*: Box
    screenBox*: Box
    offset*: Position
    totalOffset*: Position
    attrs*: set[Attributes]

    zlevel*: ZLevel
    rotation*: float32
    fill*: Color
    highlight*: Color
    transparency*: float32
    stroke*: Stroke
    cornerRadius*: (UICoord, UICoord, UICoord, UICoord)
    shadow*: Option[Shadow]

    case kind*: NodeKind
    of nkImage:
      image*: ImageStyle
    of nkText:
      textStyle*: TextStyle
      when not defined(js):
        textLayout*: seq[GlyphPosition]
      else:
        element*: Element
        textElement*: Element
        cache*: Node
    of nkDrawable:
      points*: seq[Position]
    else:
      discard

type
  HttpStatus* = enum
    Starting
    Ready
    Loading
    Error

  HttpCall* = ref object
    status*: HttpStatus
    data*: string
    json*: JsonNode
    when defined(js):
      httpRequest*: XMLHttpRequest
    else:
      future*: Future[string]


proc refresh*() =
  ## Request the screen be redrawn
  requestedFrame = max(1, requestedFrame)


proc removeExtraChildren*(node: Node) =
  ## Deal with removed nodes.
  node.nodes.setLen(node.diffIndex)

proc x*(mouse: Mouse): UICoord = mouse.pos.descaled.x
proc y*(mouse: Mouse): UICoord = mouse.pos.descaled.x

iterator reverse*[T](a: openArray[T]): T {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield a[i]
    dec i

iterator reversePairs*[T](a: openArray[T]): (int, T) {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield (a.len - 1 - i, a[i])
    dec i

iterator reverseIndex*[T](a: openArray[T]): (int, T) {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield (i, a[i])
    dec i

proc resetToDefault*(node: Node)=
  ## Resets the node to default state.
  node.box = initBox(0,0,0,0)
  node.orgBox = initBox(0,0,0,0)
  node.rotation = 0
  node.fill = clearColor
  node.transparency = 0
  node.stroke = Stroke(weight: 0, color: clearColor)
  node.image = ImageStyle(name: "", color: whiteColor)
  node.cornerRadius = (0'ui, 0'ui, 0'ui, 0'ui)
  node.shadow = Shadow.none()

proc getUrl*(): string =
  windowUrl

proc setUrl*(url: string) =
  windowUrl = url
  refresh()

proc emptyFuture*(): Future[void] =
  result = newFuture[void]()
  result.complete()

const
  MouseButtons* = [
    MouseLeft,
    MouseRight,
    MouseMiddle,
    MouseButton4,
    MouseButton5
  ]

proc setMousePos*(item: var Mouse, x, y: float64) =
  item.pos = vec2(x, y)
  item.pos *= pixelRatio / item.pixelScale
  item.delta = item.pos - item.prevPos
  item.prevPos = item.pos

proc computeScreenBox*(parent, node: Node) =
  ## Setups screenBoxes for the whole tree.
  if parent == nil:
    node.screenBox = node.box
    node.totalOffset = node.offset
  else:
    node.screenBox = node.box + parent.screenBox
    node.totalOffset = node.offset + parent.totalOffset
  for n in node.nodes:
    computeScreenBox(node, n)

proc atXY*[T: Box](rect: T, x, y: int | float32 | UICoord): T =
  result = rect
  result.x = UICoord(x)
  result.y = UICoord(y)

proc atXY*[T: Rect](rect: T, x, y: int | float32): T =
  result = rect
  result.x = x
  result.y = y

proc `+`*(rect: Rect, xy: Vec2): Rect =
  ## offset rect with xy vec2 
  result = rect
  result.x += xy.x
  result.y += xy.y

proc `~=`*(rect: Vec2, val: float32): bool =
  result = rect.x ~= val and rect.y ~= val

template dispatchEvent*(evt: typed) =
  result.add(evt)

