import std/[tables, unicode]
# import cssgrid

import commons
export commons

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var
  root* {.runtimeVar.}: Figuro
  # current* {.runtimeVar.}: Figuro
  # parent* {.runtimeVar, threadvar.}: Figuro

  redrawNodes* {.runtimeVar.}: OrderedSet[Figuro]

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


proc resetToDefault*(node: Figuro, kind: NodeKind) =
  ## Resets the node to default state.

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
  

var nodeDepth = 0
proc nd*(): string =
  for i in 0..nodeDepth:
    result &= "   "

proc setupRoot*(widget: Figuro) =
  if root == nil:
    raise newException(NilAccessDefect, "must set root")
    # root = Figuro()
    # root.zlevel = ZLevelDefault
  # root = widget
  # nodeStack = @[Figuro(root)]
  # current = root
  # current.parent = root
  root.diffIndex = 0

proc disable(fig: Figuro) =
  if not fig.isNil:
    fig.parent = nil
    fig.attrs.incl inactive
    for child in fig.children:
      disable(child)

proc removeExtraChildren*(node: Figuro) =
  ## Deal with removed nodes.
  if node.diffIndex == node.children.len:
    return
  echo nd(), "removeExtraChildren: ", node.getId, " parent: ", node.parent.getId
  for i in node.diffIndex..<node.children.len:
    disable(node.children[i])
  echo nd(), "Disable:setlen: ", node.getId, " diff: ", node.diffIndex
  node.children.setLen(node.diffIndex)

proc refresh*(node: Figuro) =
  ## Request the screen be redrawn
  # app.requestedFrame = max(1, app.requestedFrame)
  if node == nil:
    return
  app.requestedFrame.inc
  redrawNodes.incl(node)
  # assert app.frameCount < 10 or node.uid != 0

proc getTitle*(): string =
  ## Gets window title
  getWindowTitle()

template setTitle*(title: string) =
  ## Sets window title
  if (getWindowTitle() != title):
    setWindowTitle(title)
    refresh(current)


proc preNode*[T: Figuro](kind: NodeKind, id: string, current: var T, parent: Figuro) =
  ## Process the start of the node.
  mixin draw

  nodeDepth.inc()
  # echo nd(), "preNode:setup: id: ", id, " current: ", current.getId, " parent: ", parent.getId,
  #             " diffIndex: ", parent.diffIndex, " p:c:len: ", parent.children.len,
  #             " cattrs: ", if current.isNil: "{}" else: $current.attrs,
  #             " pattrs: ", if parent.isNil: "{}" else: $parent.attrs

  # TODO: maybe a better node differ?
  if parent.children.len <= parent.diffIndex:
    # parent = nodeStack[^1]
    # Create Node.
    current = T.new()
    current.uid = current.agentId
    echo nd(), "create new node: ", id, " new: ", current.uid, " parent: ", parent.uid
    current.agentId = current.uid
    parent.children.add(current)
    # current.parent = parent
    refresh(current)
  else:
    # Reuse Node.
    # echo nd(), "checking reuse node"
    if not (parent.children[parent.diffIndex] of T):
      # mismatch types, replace node
      current = T.new()
      # echo nd(), "create new replacement node: ", id, " new: ", current.uid, " parent: ", parent.uid
      parent.children[parent.diffIndex] = current
    else:
      # echo nd(), "reuse node: ", id, " new: ", current.getId, " parent: ", parent.uid
      current = T(parent.children[parent.diffIndex])

    if resetNodes == 0 and
        current.nIndex == parent.diffIndex and
        kind == current.kind:
      # Same node.
      discard
    else:
      # Big change.
      current.nIndex = parent.diffIndex
      current.resetToDefault(kind)
      refresh(current)

  # echo nd(), "preNode: Start: ", id, " current: ", current.getId, " parent: ", parent.getId

  current.parent = parent
  let name = $(id) & " " & repr(typeof(T))
  current.name.setLen(0)
  discard current.name.tryAdd(name)
  current.kind = kind
  current.highlight = parent.highlight
  current.transparency = parent.transparency
  current.zlevel = parent.zlevel

  current.listens.mouse = {}
  # current.listens.gesture = {}

  nodeStack.add(current)
  inc parent.diffIndex
  current.diffIndex = 0

  connect(current, onDraw, current, Figuro.clearDraw())
  connect(current, onDraw, current, typeof(current).draw())
  connect(current, onDraw, current, Figuro.handlePostDraw())
  emit current.onDraw()

proc postNode*(current: var Figuro) =
  if not current.postDraw.isNil:
    current.postDraw(current)

  current.removeExtraChildren()
  nodeDepth.dec()

import utils

template node*(kind: NodeKind, id: string, blk: untyped): untyped =
  ## Base template for node, frame, rectangle...
  block:
    var parent: Figuro = current
    var current {.inject.}: Figuro = nil
    preNode(kind, id, current, parent)
    let x = id
    captureArgs x:
      current.postDraw = proc (widget: Figuro) =
        # echo nd(), "node:postDraw: ", widget.getId
        var current {.inject.}: Figuro = widget
        # echo "BUTTON: ", current.getId, " parent: ", current.parent.getId
        # let widget {.inject.} = Button[T](current)
        if postDrawReady in widget.attrs:
          widget.attrs.excl postDrawReady
          `blk`
    postNode(current)

# template node*(kind: NodeKind, id: string, blk: untyped): untyped =
#   node(kind, id, void, blk)

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

  for n in node.children:
    computeScreenBox(node, n, depth + 1)

proc mouseOverlaps*(node: Figuro): bool =
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
  let res = predicate
  when ET is MouseEventKinds:
    if evt in node.listens.mouse and res:
      result.incl(evt)
    if evt in node.listens.mouseSignals and res:
      result.incl(evt)
  elif ET is GestureEventType:
    if evt in node.listens.gesture and res:
      result.incl(evt)
    if evt in node.listens.gestureSignals and res:
      result.incl(evt)

proc checkMouseEvents*(node: Figuro): MouseEventFlags =
  ## Compute mouse events
  if node.mouseOverlaps():
    node.checkEvent(evClick, uxInputs.mouse.click())
    node.checkEvent(evPress, uxInputs.mouse.down())
    node.checkEvent(evRelease, uxInputs.mouse.release())
    node.checkEvent(evOverlapped, true)
    node.checkEvent(evHover, true)

type
  EventsCapture*[T: set] = object
    zlvl*: ZLevel
    flags*: MouseEventFlags
    targets*: HashSet[Figuro]
    buttons*: UiButtonView

  MouseCapture* = EventsCapture[MouseEventFlags]
  KeyboardCapture* = EventsCapture[KeyboardEventFlags]
  
  CapturedEvents* = object
    mouse*: array[MouseEventKinds, MouseCapture]
    keyboard*: array[KeyboardEventKinds, KeyboardCapture]

proc maxEvt[T](a, b: EventsCapture[T]): EventsCapture[T] =
  if b.zlvl >= a.zlvl and b.flags != {}: b
  else: a

proc consumeMouseButtons(mouseEvts: MouseEventFlags): array[MouseEventKinds, UiButtonView] =
  ## Consume mouse buttons
  ## 
  if evPress in mouseEvts:
    result[evPress] = uxInputs.buttonPress * MouseButtons
    uxInputs.buttonPress.excl MouseButtons
  if evDown in mouseEvts:
    result[evDown] = uxInputs.buttonDown * MouseButtons
    uxInputs.buttonDown.excl MouseButtons
  if evRelease in mouseEvts:
    result[evRelease] = uxInputs.buttonRelease * MouseButtons
    uxInputs.buttonRelease.excl MouseButtons
  if evClick in mouseEvts:
    when defined(clickOnDown):
      result[evPress] = uxInputs.buttonPress * MouseButtons
      result[evClick] = result[evRelease]
      uxInputs.buttonPress.excl MouseButtons
    else:
      result[evRelease] = uxInputs.buttonRelease * MouseButtons
      result[evClick] = result[evRelease]
      uxInputs.buttonRelease.excl MouseButtons

proc computeNodeEvents*(node: Figuro): CapturedEvents =
  ## Compute mouse events
  ## 
  for n in node.children.reverse:
    let child = computeNodeEvents(n)
    for ek in MouseEventKinds:
      result.mouse[ek] = maxEvt(result.mouse[ek], child.mouse[ek])
    # result.gesture = max(result.gesture, child.gesture)

  let
    mouseEvts = node.checkMouseEvents()
    buttons = mouseEvts.consumeMouseButtons()

  for ek in MouseEventKinds:
    let captured = MouseCapture(zlvl: node.zlevel,
                                flags: mouseEvts * {ek},
                                buttons: buttons[ek],
                                targets: toHashSet([node]))

    if clipContent in node.attrs and not node.mouseOverlaps():
      # this node clips events, so it must overlap child events, 
      # e.g. ignore child captures if this node isn't also overlapping 
      result.mouse[ek] = captured
    elif ek == evHover and evHover in mouseEvts:
      result.mouse[ek].targets.incl(captured.targets)
      result.mouse[ek].targets.incl(result.mouse[ek].targets)
      result.mouse[ek].flags.incl(evHover)
    else:
      result.mouse[ek] = maxEvt(captured, result.mouse[ek])
      # result.gesture = max(captured.gesture, result.gesture)

  # echo "computeNodeEvents:result:post: ", result.mouse.flags, " :: ", result.mouse.target.uid

var
  prevHovers {.runtimeVar.}: HashSet[Figuro]
  prevClicks {.runtimeVar.}: HashSet[Figuro]

proc computeEvents*(node: Figuro) =
  ## mouse and gesture are handled separately as they can have separate
  ## node targets

  if redrawNodes.len() == 0 and
      uxInputs.mouse.consumed and
      uxInputs.keyboard.consumed and
      prevHovers.len == 0:
    return

  var captured: CapturedEvents = computeNodeEvents(node)

  # set mouse event flags in targets
  for ek in MouseEventKinds:
    let evts = captured.mouse[ek]
    for target in evts.targets:
      for target in evts.targets:
        target.events.mouse.incl evts.flags

  # Mouse
  # let mouseButtons = uxInputs.buttonRelease * MouseButtons
  
  printNewEventInfo()

  if captured.mouse[evHover].targets != prevHovers:
    let hoverTargets = captured.mouse[evHover].targets
    let newHovers = hoverTargets - prevHovers
    let delHovers = prevHovers - hoverTargets

    for target in newHovers:
      target.events.mouse.incl evHover
      emit target.onHover(Enter)
      target.refresh()
      prevHovers.incl target

    for target in delHovers:
      target.events.mouse.excl evHover
      emit target.onHover(Exit)
      target.refresh()
      prevHovers.excl target

  let click = captured.mouse[evClick]
  if click.targets.len() > 0 and evClick in click.flags:
    let clickTargets = captured.mouse[evClick].targets
    let newClicks = clickTargets
    let delClicks = prevClicks - clickTargets

    for target in delClicks:
        target.events.mouse.excl evClick
        emit target.onClick(Exit, click.buttons)
        prevClicks.excl target

    for target in newClicks:
        target.events.mouse.incl evClick
        emit target.onClick(Enter, click.buttons)
        prevClicks.incl target

  uxInputs.buttonPress.excl MouseButtons
  uxInputs.buttonDown.excl MouseButtons
  uxInputs.buttonRelease.excl MouseButtons

  uxInputs.mouse.consumed = true
  uxInputs.keyboard.consumed = true
