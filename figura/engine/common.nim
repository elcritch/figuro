import std/[sequtils, tables, json, hashes]
import std/[typetraits, options, unicode, strformat]
import pkg/[variant, chroma, cssgrid, windy]

import commonutils
import cdecl/atoms

export sequtils, strformat, tables, hashes
export variant
# export unicode
export commonutils
export cssgrid
export atoms

import pretty

when defined(js):
  import dom2, html/ajax
else:
  import typography, asyncfutures

const
  clearColor* = color(0, 0, 0, 0)
  whiteColor* = color(1, 1, 1, 1)
  blackColor* = color(0, 0, 0, 1)

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

  
  KeyState* = enum
    Empty
    Up
    Down
    Repeat
    Press # Used for text input

  MouseCursorStyle* = enum
    Default
    Pointer
    Grab
    NSResize

  Mouse* = ref object
    pos*: Vec2
    delta*: Vec2
    prevPos*: Vec2
    pixelScale*: float32
    wheelDelta*: float32
    cursorStyle*: MouseCursorStyle ## Sets the mouse cursor icon
    prevCursorStyle*: MouseCursorStyle
    consumed*: bool ## Consumed - need to prevent default action.
    clickedOutside*: bool ## 

  Keyboard* = ref object
    state*: KeyState
    consumed*: bool ## Consumed - need to prevent default action.
    keyString*: string
    altKey*: bool
    ctrlKey*: bool
    shiftKey*: bool
    superKey*: bool
    focusNode*: Node
    onFocusNode*: Node
    onUnFocusNode*: Node
    input*: seq[Rune]
    textCursor*: int ## At which character in the input string are we
    selectionCursor*: int ## To which character are we selecting to
  
  MouseEventType* {.size: sizeof(int16).} = enum
    evClick
    evClickOut
    evHover
    evHoverOut
    evOverlapped
    evPress
    evRelease

  KeyboardEventType* {.size: sizeof(int16).} = enum
    evKeyboardInput
    evKeyboardFocus
    evKeyboardFocusOut

  GestureEventType* {.size: sizeof(int16).} = enum
    evScroll
    evDrag # TODO: implement this!?

  MouseEventFlags* = set[MouseEventType]
  KeyboardEventFlags* = set[KeyboardEventType]
  GestureEventFlags* = set[GestureEventType]

  InputEvents* = object
    mouse*: MouseEventFlags
    gesture*: GestureEventFlags
  ListenEvents* = object
    mouse*: MouseEventFlags
    gesture*: GestureEventFlags

  EventsCapture*[T] = object
    zlvl*: ZLevel
    flags*: T
    target*: Node

  MouseCapture* = EventsCapture[MouseEventFlags] 
  GestureCapture* = EventsCapture[GestureEventFlags] 

  CapturedEvents = object
    mouse*: MouseCapture
    gesture*: GestureCapture

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

type
    MouseEvent* = object
      case kind*: MouseEventType
      of evClick: discard
      of evClickOut: discard
      of evHover: discard
      of evHoverOut: discard
      of evOverlapped: discard
      of evPress: discard
      of evRelease: discard

    KeyboardEvent* = object
      case kind*: KeyboardEventType
      of evKeyboardInput: discard
      of evKeyboardFocus: discard
      of evKeyboardFocusOut: discard

    GestureEvent* = object
      case kind*: GestureEventType
      of evScroll: discard
      of evDrag: discard

proc toEvent*(kind: MouseEventType): MouseEvent =
  MouseEvent(kind: kind)
proc toEvent*(kind: KeyboardEventType): KeyboardEvent =
  KeyboardEvent(kind: kind)
proc toEvent*(kind: GestureEventType): GestureEvent =
  GestureEvent(kind: kind)

const
  DataDirPath* {.strdefine.} = "data"

var
  parent*: Node
  root*: Node

  nodeStack*: seq[Node]
  gridStack*: seq[GridTemplate]
  current*: Node
  scrollBox*: Box
  scrollBoxMega*: Box ## Scroll box is 500px bigger in y direction
  scrollBoxMini*: Box ## Scroll box is smaller by 100px useful for debugging
  mouse* = Mouse()
  keyboard* = Keyboard()
  requestedFrame*: int
  numNodes*: int
  popupActive*: bool
  inPopup*: bool
  resetNodes*: int
  popupBox*: Box
  fullscreen* = false
  windowLogicalSize*: Vec2 ## Screen size in logical coordinates.
  windowSize*: Vec2    ## Screen coordinates
  # windowFrame*: Vec2   ## Pixel coordinates
  pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels
  pixelScale*: float32 ## Pixel multiplier user wants on the UI

  # Used to check for duplicate ID paths.
  pathChecker*: Table[string, bool]

  computeTextLayout*: proc(node: Node)

  lastUId: int
  nodeLookup*: Table[string, Node]

  dataDir*: string = DataDirPath

  ## Used for HttpCalls
  httpCalls*: Table[string, HttpCall]

  # UI Scale
  uiScale*: float32 = 1.0
  autoUiScale*: bool = true

  defaultlineHeightRatio* = 1.618.UICoord ##\
    ## see https://medium.com/@zkareemz/golden-ratio-62b3b6d4282a
  adjustTopTextFactor* = 1/16.0 # adjust top of text box for visual balance with descender's -- about 1/8 of fonts, so 1/2 that

  # global scroll bar settings
  scrollBarFill* = rgba(187, 187, 187, 162).color 
  scrollBarHighlight* = rgba(137, 137, 137, 162).color

  buttonPress: windy.ButtonView
  buttonDown: windy.ButtonView
  buttonRelease: windy.ButtonView

proc defaultLineHeight*(fontSize: UICoord): UICoord =
  result = fontSize * defaultlineHeightRatio
proc defaultLineHeight*(ts: TextStyle): UICoord =
  result = defaultLineHeight(ts.fontSize)

proc init*(tp: typedesc[Stroke], weight: float32|UICoord, color: string, alpha = 1.0): Stroke =
  ## Sets stroke/border color.
  result.color = parseHtmlColor(color)
  result.color.a = alpha
  result.weight = weight.float32

proc init*(tp: typedesc[Stroke], weight: float32|UICoord, color: Color, alpha = 1.0): Stroke =
  ## Sets stroke/border color.
  result.color = color
  result.color.a = alpha
  result.weight = weight.float32

proc newUId*(): NodeUID =
  # Returns next numerical unique id.
  inc lastUId
  when defined(js) or defined(StringUID):
    $lastUId
  else:
    NodeUID(lastUId)

proc imageStyle*(name: string, color: Color): ImageStyle =
  # Image style
  result = ImageStyle(name: name, color: color)

when not defined(js):
  var
    # currTextBox*: TextBox[Node]
    fonts*: Table[string, Font]

  func hAlignMode*(align: HAlign): HAlignMode =
    case align:
      of hLeft: HAlignMode.Left
      of hCenter: Center
      of hRight: HAlignMode.Right

  func vAlignMode*(align: VAlign): VAlignMode =
    case align:
      of vTop: Top
      of vCenter: Middle
      of vBottom: Bottom

mouse = Mouse()
mouse.pos = vec2(0, 0)

# proc `$`*(a: Rect): string =
  # fmt"({a.x:6.2f}, {a.y:6.2f}; {a.w:6.2f}x{a.h:6.2f})"

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

proc setupRoot*() =
  if root == nil:
    root = Node()
    root.uid = newUId()
    root.zlevel = ZLevelDefault
  nodeStack = @[root]
  current = root
  root.diffIndex = 0

proc emptyFuture*(): Future[void] =
  result = newFuture[void]()
  result.complete()

proc clearInputs*() =
  resetNodes = 0
  mouse.wheelDelta = 0
  mouse.consumed = false
  mouse.clickedOutside = false

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

proc mouseOverlapsNode*(node: Node): bool =
  ## Returns true if mouse overlaps the node node.
  let mpos = mouse.pos.descaled + node.totalOffset 
  let act = 
    (not popupActive or inPopup) and
    node.screenBox.w > 0'ui and
    node.screenBox.h > 0'ui 

  result =
    act and
    mpos.overlaps(node.screenBox) and
    (if inPopup: mouse.pos.descaled.overlaps(popupBox) else: true)

const
  MouseOnOutEvents = {evClickOut, evHoverOut, evOverlapped}


template calcBasicConstraintImpl(
    parent, node: Node,
    dir: static GridDir,
    f: untyped
) =
  ## computes basic constraints for box'es when set
  ## this let's the use do things like set 90'pp (90 percent)
  ## of the box width post css grid or auto constraints layout
  template calcBasic(val: untyped): untyped =
    block:
      var res: UICoord
      match val:
        UiFixed(coord):
          res = coord.UICoord
        UiFrac(frac):
          res = frac.UICoord * parent.box.f
        UiPerc(perc):
          let ppval = when astToStr(f) == "x": parent.box.w
                      elif astToStr(f) == "y": parent.box.h
                      else: parent.box.f
          res = perc.UICoord / 100.0.UICoord * ppval
      res
  
  let csValue = when astToStr(f) in ["w", "h"]: node.cxSize[dir] 
                else: node.cxOffset[dir]
  match csValue:
    UiAuto():
      when astToStr(f) in ["w", "h"]:
        node.box.f = parent.box.f
      else:
        discard
    UiSum(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = lv + rv
    UiMin(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = min(lv, rv)
    UiMax(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = max(lv, rv)
    UiValue(value):
      node.box.f = calcBasic(value)
    _:
      discard

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

template to*[V, T](events: Events[T], v: typedesc[V]): Events[V] =
  Events[V](events)

proc add*[T, V](events: var Events[V], evt: T) =
  if events.data.isNil:
    events.data = newTable[TypeId, Variant]()
  let key = T.getTypeId()
  let res = events.data.mgetOrPut(key, newVariant(new seq[T])).get(ref seq[T])
  res[].add(evt)

proc `[]`*[T](events: Events[void], tp: typedesc[T]): seq[T] =
  if events.data.isNil:
    return @[]
  let key = T.getTypeId()
  result = events.data.pop(key)

import std/monotimes, std/times

proc popEvents*[T, V](events: Events[V], vals: var seq[T]): bool =
  # let a = getMonoTime()
  if events.data.isNil:
    return false
  var res: Variant
  result = events.data.pop(T.getTypeId(), res)
  if result:
    vals = res.get(ref seq[T])[]
  # let b = getMonoTime()
  # echo "popEvents: ", $inNanoseconds(b-a), "ns"


template dispatchEvent*(evt: typed) =
  result.add(evt)

import std/macrocache
const mcStateCounter = CacheCounter"stateCounter"

template useStateImpl[T: ref](node: Node, vname: untyped) =
  ## creates and caches a new state ref object
  const id = static:
    hash(astToStr(vname))
  if not node.userStates.hasKey(id):
    node.userStates[id] = newVariant(T.new())
  var `vname` {.inject.} = node.userStates[id].get(typeof T)

template useState*[T: ref](vname: untyped) =
  ## creates and caches a new state ref object
  useStateImpl[T](common.current, vname)

template useStateParent*[T: ref](vname: untyped) =
  ## creates and caches a new state ref object
  useStateImpl[T](common.parent, vname)

template withState*[T: ref](tp: typedesc[T]): untyped =
  ## creates and caches a new state ref object
  block:
    const id = 
      static:
        mcStateCounter.inc(1)
        value(mcStateCounter)

    if not current.userStates.hasKey(id):
      current.userStates[id] = newVariant(tp.new())
    current.userStates[id].get(tp)

template toRunes*(item: Node): seq[Rune] =
  item.text
