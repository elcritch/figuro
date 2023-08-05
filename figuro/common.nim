import std/[sequtils, tables, json, hashes]
import std/[options, unicode, strformat]
import std/locks
# import std/asyncdispatch
import pkg/[variant, chroma, cssgrid, windy]

import cdecl/atoms
import ./[commonutils, inputs]

export sequtils, strformat, tables, hashes
export variant
# export unicode
export commonutils
export cssgrid
export atoms
export inputs

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

  dataDir*: string = DataDirPath


type
  NodeUID* = int64



type
  All* = distinct object
  # Events* = GenericEvents[void]
  Events*[T] = object
    data*: TableRef[TypeId, Variant]

when not defined(js):
  var
    # currTextBox*: TextBox[Node]
    fonts*: Table[string, Font]

proc removeExtraChildren*(node: Node) =
  ## Deal with removed nodes.
  node.nodes.setLen(node.diffIndex)

proc x*(mouse: Mouse): UICoord = mouse.pos.descaled.x
proc y*(mouse: Mouse): UICoord = mouse.pos.descaled.x


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

proc atXY*[T: Box](rect: T, x, y: int | float32): T =
  result = rect
  result.x = UICoord(x)
  result.y = UICoord(y)

proc atXY*[T: Box](rect: T, x, y: UICoord): T =
  result = rect
  result.x = x
  result.y = y

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

