import std/[tables, unicode]
# import cssgrid

import commons
export commons

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var
  root* {.runtimeVar.}: FiguroApp
  parent* {.runtimeVar.}: Figuro
  current* {.runtimeVar.}: Figuro

  nodeStack* {.runtimeVar.}: seq[Figuro]
  # gridStack*: seq[GridTemplate]

  scrollBox* {.runtimeVar.}: Box
  scrollBoxMega* {.runtimeVar.}: Box ## Scroll box is 500px bigger in y direction
  scrollBoxMini* {.runtimeVar.}: Box ## Scroll box is smaller by 100px useful for debugging

  numNodes* {.runtimeVar.}: int
  popupActive* {.runtimeVar.}: bool
  inPopup* {.runtimeVar.}: bool
  resetNodes* {.runtimeVar.}: int
  popupBox* {.runtimeVar.}: Box

  # Used to check for duplicate ID paths.
  pathChecker* {.runtimeVar.}: Table[string, bool]

  computeTextLayout* {.runtimeVar.}: proc(node: Figuro)

  nodeLookup* {.runtimeVar.}: Table[string, Figuro]

  defaultlineHeightRatio* {.runtimeVar.} = 1.618.UICoord ##\
    ## see https://medium.com/@zkareemz/golden-ratio-62b3b6d4282a
  adjustTopTextFactor* {.runtimeVar.} = 1/16.0 # adjust top of text box for visual balance with descender's -- about 1/8 of fonts, so 1/2 that

  # global scroll bar settings
  scrollBarFill* {.runtimeVar.} = rgba(187, 187, 187, 162).color 
  scrollBarHighlight* {.runtimeVar.} = rgba(137, 137, 137, 162).color

  # buttonPress*: ButtonView
  # buttonDown*: ButtonView
  # buttonRelease*: ButtonView


# inputs.keyboardInput = proc (rune: Rune) =
#     app.requestedFrame.inc
#     # if keyboard.focusNode != nil:
#     #   keyboard.state = KeyState.Press
#     #   # currTextBox.typeCharacter(rune)
#     # else:
#     #   keyboard.state = KeyState.Press
#     #   keyboard.keyString = rune.toUTF8()
#     appEvent.trigger()

proc resetToDefault*(node: Figuro, kind: NodeKind) =
  ## Resets the node to default state.

  node.kind = kind
  # node.id = ""
  # node.uid = ""
  # node.idPath = ""
  # node.kind = nkRoot
  # node.text = "".toRunes()
  # node.code = ""
  # node.nodes = @[]
  node.box = initBox(0,0,0,0)
  node.orgBox = initBox(0,0,0,0)
  node.rotation = 0
  # node.screenBox = rect(0,0,0,0)
  # node.offset = vec2(0, 0)
  node.fill = clearColor
  node.transparency = 0
  node.stroke = Stroke(weight: 0, color: clearColor)
  # node.textStyle = TextStyle()
  # node.image = ImageStyle(name: "", color: whiteColor)
  node.cornerRadius = 0'ui
  # node.shadow = Shadow.none()
  node.diffIndex = 0
  node.zlevel = ZLevelDefault
  # node.editableText = false
  # node.multiline = false
  # node.bindingSet = false
  # node.drawable = false
  # node.cursorColor = clearColor
  # node.highlightColor = clearColor
  # node.gridTemplate = nil
  # node.gridItem = nil
  # node.constraintsHorizontal = cMin
  # node.constraintsVertical = cMin
  # node.layoutAlign = laMin
  # node.layoutMode = lmNone
  # node.counterAxisSizingMode = csAuto
  # node.horizontalPadding = 0'ui
  # node.verticalPadding = 0'ui
  # node.itemSpacing = 0'ui
  # node.clipContent = false
  # node.selectable = false
  # node.scrollpane = false
  # node.hasRendered = false
  # node.userStates = initTable[int, Variant]()

proc setupRoot*(widget: Figuro) =
  if root == nil:
    raise newException(NilAccessDefect, "must set root")
    # root = Figuro()
    # root.uid = newUId()
    # root.zlevel = ZLevelDefault
  # root = widget
  nodeStack = @[Figuro(root)]
  current = root
  root.diffIndex = 0

proc removeExtraChildren*(node: Figuro) =
  ## Deal with removed nodes.
  node.children.setLen(node.diffIndex)

proc refresh*() =
  ## Request the screen be redrawn
  app.requestedFrame = max(1, app.requestedFrame)

proc getTitle*(): string =
  ## Gets window title
  getWindowTitle()

proc setTitle*(title: string) =
  ## Sets window title
  if (getWindowTitle() != title):
    setWindowTitle(title)
    refresh()

proc preNode*[T: Figuro](kind: NodeKind, tp: typedesc[T], id: string) =
  ## Process the start of the node.
  mixin draw

  parent = nodeStack[^1]

  # TODO: maybe a better node differ?
  if parent.children.len <= parent.diffIndex:
    # Create Node.
    current = T()
    current.uid = newUId()
    parent.children.add(current)
    refresh()
  else:
    # Reuse Node.
    current = parent.children[parent.diffIndex]

    if not (current of T):
      # mismatch types, replace node
      echo "new type"
      current = T()
      parent.children[parent.diffIndex] = current

    if resetNodes == 0 and
        current.nIndex == parent.diffIndex and
        kind == current.kind:
      # Same node.
      discard
    else:
      # Big change.
      current.nIndex = parent.diffIndex
      current.resetToDefault(kind)
      refresh()

  {.cast(uncheckedAssign).}:
    current.kind = kind
  # current.textStyle = parent.textStyle
  # current.cursorColor = parent.cursorColor
  current.highlight = parent.highlight
  current.transparency = parent.transparency
  current.zlevel = parent.zlevel

  current.listens.mouse = {}
  current.listens.gesture = {}

  nodeStack.add(current)
  inc parent.diffIndex

  current.diffIndex = 0
  # draw(T(current))
  connect(current, onDraw, current, T.draw)
  emit current.onDraw()

proc postNode*() =
  current.removeExtraChildren()
  current.events.mouse = {}
  current.events.gesture = {}

  # Pop the stack.
  discard nodeStack.pop()
  if nodeStack.len > 1:
    current = nodeStack[^1]
  else:
    current = nil
  if nodeStack.len > 2:
    parent = nodeStack[^2]
  else:
    parent = nil

template node*(kind: NodeKind, id: static string, inner, setup: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, Figuro, id)
  setup
  inner
  postNode()

template node*(kind: NodeKind, id: static string, inner: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, Figuro, id)
  inner
  postNode()

proc computeScreenBox*(parent, node: Figuro, depth: int = 0) =
  ## Setups screenBoxes for the whole tree.
  if parent == nil:
    node.box.w = app.windowSize.x
    node.box.h = app.windowSize.y
    node.screenBox = node.box
    node.totalOffset = node.offset
  else:
    node.screenBox = node.box + parent.screenBox
    node.totalOffset = node.offset + parent.totalOffset

  # if depth == 0: echo ""
  # var sp = ""
  # for i in 0..depth: sp &= "  "
  # echo "node: ", sp, node.uid, " ", node.screenBox

  for n in node.children:
    computeScreenBox(node, n, depth + 1)

const
  MouseOnOutEvents = {evClickOut, evHoverOut, evOverlapped}

proc max[T](a, b: EventsCapture[T]): EventsCapture[T] =
  if b.zlvl >= a.zlvl and b.flags != {}: b else: a

proc mouseOverlapsNode*(node: Figuro): bool =
  ## Returns true if mouse overlaps the node node.
  let mpos = uxInputs.mouse.pos + node.totalOffset 
  let act = 
    (not popupActive or inPopup) and
    node.screenBox.w > 0'ui and
    node.screenBox.h > 0'ui 

  result =
    act and
    mpos.overlaps(node.screenBox) and
    (if inPopup: uxInputs.mouse.pos.overlaps(popupBox) else: true)

template checkEvent[ET](node: typed, evt: ET, predicate: typed) =
  when ET is MouseEventType:
    if evt in node.listens.mouse and predicate: result.incl(evt)
  elif ET is GestureEventType:
    if evt in node.listens.gesture and predicate: result.incl(evt)

proc checkMouseEvents*(node: Figuro): MouseEventFlags =
  ## Compute mouse events
  if node.kind != nkFrame and node.mouseOverlapsNode():
    node.checkEvent(evClick, uxInputs.mouse.click())
    node.checkEvent(evPress, uxInputs.mouse.down())
    node.checkEvent(evRelease, uxInputs.mouse.release())
    node.checkEvent(evHover, true)
    node.checkEvent(evOverlapped, true)
    # if result != {}:
    #   echo "mouse hover: ", result, " ", node.uid
  else:
    node.checkEvent(evClickOut, uxInputs.mouse.click())
    node.checkEvent(evHoverOut, true)

proc checkGestureEvents*(node: Figuro): GestureEventFlags =
  ## Compute gesture events
  if node.mouseOverlapsNode():
    node.checkEvent(evScroll, uxInputs.mouse.scrolled())

proc computeNodeEvents*(node: Figuro): CapturedEvents =
  ## Compute mouse events
  for n in node.children.reverse:
    let child = computeNodeEvents(n)
    result.mouse = max(result.mouse, child.mouse)
    result.gesture = max(result.gesture, child.gesture)

  let
    allMouseEvts = node.checkMouseEvents()
    mouseOutEvts = allMouseEvts * MouseOnOutEvents
    mouseEvts = allMouseEvts - MouseOnOutEvents
    gestureEvts = node.checkGestureEvents()

  # set on-out events 
  node.events.mouse.incl(mouseOutEvts)

  if node.events.mouse != {}:
    echo "computeNodeEvents: ", node.events.mouse

  let
    captured = CapturedEvents(
      mouse: MouseCapture(zlvl: node.zlevel, flags: mouseEvts, target: node),
      gesture: GestureCapture(zlvl: node.zlevel, flags: gestureEvts, target: node)
    )

  if clipContent in node.attrs and not node.mouseOverlapsNode():
    # this node clips events, so it must overlap child events, 
    # e.g. ignore child captures if this node isn't also overlapping 
    result = captured
  else:
    result.mouse = max(captured.mouse, result.mouse)
    result.gesture = max(captured.gesture, result.gesture)
  

proc computeEvents*(node: Figuro) =
  let res = computeNodeEvents(node)
  template handleCapture(name, field, ignore: untyped) =
    ## process event capture
    # TODO: do we need this? can signals replace it?
    if not res.`field`.target.isNil:
      let evts = res.`field`
      let target = evts.target
      target.events.`field` = evts.flags
      if target.kind != nkFrame and evts.flags - ignore != {}:
        # echo "EVT: ", target.kind, " => ", evts.flags, " @ ", target.id
        # app.requestedFrame = 2
        discard

  ## mouse and gesture are handled separately as they can have separate
  ## node targets
  handleCapture("mouse", mouse, {evHover})
  handleCapture("gesture", gesture, {})