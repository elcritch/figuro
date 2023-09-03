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
  echo "\n\nDisable: ", fig.getId
  echo ""
  stdout.write("HEYA")
  stdout.flushFile()
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
  echo nd(), "preNode:setup: id: ", id, " current: ", current.getId, " parent: ", parent.getId,
              " diffIndex: ", parent.diffIndex, " p:c:len: ", parent.children.len,
              " cattrs: ", if current.isNil: "{}" else: $current.attrs,
              " pattrs: ", if parent.isNil: "{}" else: $parent.attrs

  # TODO: maybe a better node differ?
  if drawing in parent.attrs and
      parent.children.len <= parent.diffIndex:
    # parent = nodeStack[^1]
    # Create Node.
    current = T.new()
    current.uid = current.agentId
    echo nd(), "create new node: ", id, " new: ", current.uid, " parent: ", parent.uid
    current.agentId = current.uid
    parent.children.add(current)
    # current.parent = parent
    refresh(current)
  elif parent == nil and current != nil and drawing notin current.attrs:
    echo nd(), "reuse node - already created"
  else:
    # Reuse Node.
    echo nd(), "checking reuse node"
    if not (parent.children[parent.diffIndex] of T):
      # mismatch types, replace node
      current = T.new()
      echo nd(), "create new replacement node: ", id, " new: ", current.uid, " parent: ", parent.uid
      parent.children[parent.diffIndex] = current
    else:
      echo nd(), "reuse node: ", id, " new: ", current.getId, " parent: ", parent.uid
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

  echo nd(), "preNode: Start: ", id, " current: ", current.getId, " parent: ", parent.getId
  
  current.parent = parent
  let name = $(id) & " " & repr(typeof(T))
  echo "SET NAME: ", name
  current.name.setLen(0)
  discard current.name.tryAdd(name)
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
  # TODO: which is better?
  # draw(T(current))

  current.attrs.incl drawing
  current.attrs.incl postDrawReady

  connect(current, onDraw, current, Figuro.clearDraw())
  connect(current, onDraw, current, typeof(current).draw())
  connect(current, onDraw, current, Figuro.handlePostDraw())
  emit current.onDraw()

proc postNode*(current: var Figuro) =
  if not current.postDraw.isNil:
    current.postDraw(current)

  current.removeExtraChildren()
  current.attrs.excl drawing
  nodeDepth.dec()
  # Pop the stack.
  # current = current.parent
  # parent = current.parent

from sugar import capture
import macros

macro captureArgs*(args, blk: untyped): untyped =
  result = nnkCommand.newTree(bindSym"capture")
  if args.kind in [nnkSym, nnkIdent]:
    if args.strVal != "void":
      result.add args
  else:
    for arg in args:
      result.add args
  # result.add ident"parent"
  # result.add ident"current"
  if result.len() == 0:
    result = nnkEmpty.newNimNode
  result.add nnkStmtList.newTree(blk)
  echo "captured: ", result.repr

template node*(kind: NodeKind, id: string, blk: untyped): untyped =
  ## Base template for node, frame, rectangle...
  block:
    var parent: Figuro = current
    var current {.inject.}: Figuro = nil
    preNode(kind, id, current, parent)
    let x = id
    captureArgs x:
      current.postDraw = proc (widget: Figuro) =
        echo nd(), "node:postDraw: ", widget.getId
        var current {.inject.}: Figuro = widget
        current.diffIndex = 0
        # echo "BUTTON: ", current.getId, " parent: ", current.parent.getId
        # let widget {.inject.} = Button[T](current)
        if postDrawReady in widget.attrs:
          widget.attrs.excl postDrawReady
          `blk`
    postNode(current)

# template node*(kind: NodeKind, id: string, blk: untyped): untyped =
#   node(kind, id, void, blk)

macro statefulWidgetProc*(): untyped =
  ident(repr(genSym(nskProc, "doPost")))

# macro statefulWidget*(p: untyped): untyped =
#   ## implements a stateful widget template constructors where 
#   ## the type and the name are taken from the template definition:
#   ## 
#   ##    template `name`*[`type`, T](id: string, value: T, blk: untyped) {.statefulWidget.}
#   ## 
#   # echo "figuroWidget: ", p.treeRepr
#   p.expectKind nnkTemplateDef
#   let name = p.name()
#   let genericParams = p[2]
#   let typ = genericParams[0][0]
#   p.params()[0].expectKind(nnkEmpty) # no return type
#   if genericParams.len() > 1:
#     error("incorrect generic types: " & repr(genericParams) & "; " & "Should be `[WidgetType, T]`", genericParams)
#   if p.params()[1].repr() != "id: string":
#     error("incorrect arguments: " & repr(p.params()[1]) & "; " & "Should be `id: string`", p.params()[1])
#   if p.params()[2][1].repr() != genericParams[0][1].repr:
#     error("incorrect arguments: " & repr(p.params()[2][1]) & "; " & "Should be `" & genericParams[0][1].repr & "`", p.params()[2][1])
#   if p.params()[3][1].repr() != "untyped":
#     error("incorrect arguments: " & repr(p.params()[3][1]) & "; " & "Should be `untyped`", p.params()[3][1])
#   # echo "figuroWidget: ", " name: ", name, " typ: ", typ
#   # echo "\n"
#   # echo "doPostId: ", doPostId, " li: ", lineInfo(p.name())
#   result = quote do:
#     mkStatefulWidget(`typ`, `name`, doPostId)

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
    if evt in node.listens.mouse and predicate:
      result.incl(evt)
    if evt in node.listens.mouseSignals and predicate:
      result.incl(evt)
  elif ET is GestureEventType:
    if evt in node.listens.gesture and predicate:
      result.incl(evt)
    if evt in node.listens.gestureSignals and predicate:
      result.incl(evt)

proc checkMouseEvents*(node: Figuro): MouseEventFlags =
  ## Compute mouse events
  if node.mouseOverlapsNode():
    node.checkEvent(evClick, uxInputs.mouse.click())
    node.checkEvent(evPress, uxInputs.mouse.down())
    node.checkEvent(evRelease, uxInputs.mouse.release())
    node.checkEvent(evHover, true)
    node.checkEvent(evOverlapped, true)
    if uxInputs.mouse.click():
      result.incl evClickOut

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
    # mouseOutEvts = allMouseEvts * MouseOnOutEvents
    mouseEvts = allMouseEvts
    gestureEvts = node.checkGestureEvents()

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

  # echo "computeNodeEvents:result:post: ", result.mouse.flags, " :: ", result.mouse.target.uid

var
  prevHover {.runtimeVar.}: Figuro
  prevClick {.runtimeVar.}: Figuro

proc computeEvents*(node: Figuro) =
  ## mouse and gesture are handled separately as they can have separate
  ## node targets
  if uxInputs.mouse.consumed and uxInputs.keyboard.consumed:
    return

  var captured: CapturedEvents = computeNodeEvents(node)

  # Gestures
  if not captured.gesture.target.isNil:
    let evts = captured.gesture
    let target = evts.target
    target.events.gesture = evts.flags

  # Mouse
  let mouseButtons = uxInputs.buttonPress * MouseButtons
  let evts = captured.mouse
  let target = evts.target
  if not target.isNil:
    target.events.mouse.incl evts.flags

  if evts.flags != {} and evts.flags != {evHover}:
    echo "mouse events: ", "tgt: ", target.getId, " prevClick: ", prevClick.getId, " evts: ", evts.flags

  proc contains(fig: Figuro, evt: MouseEventType): bool =
    not fig.isNil and evt in fig.events.mouse

  if not uxInputs.mouse.consumed:
    if evHover in prevHover:
      if prevHover.getId != target.getId:
        prevHover.events.mouse.excl evHover
        emit prevHover.onHover(Exit)
        prevHover.refresh()
        prevHover = nil
    if evHover in target:
      if prevHover.getId != target.getId:
        emit target.onHover(Enter)
        refresh(target)
        prevHover = target

  if not uxInputs.keyboard.consumed:
    if evClickOut in target:
      target.events.mouse.excl evClickOut
      if prevClick != nil and prevClick.getId != target.getId:
        prevClick.events.mouse.excl evClick
        emit prevClick.onClick(Exit, mouseButtons)
        # prevClick.refresh()
        prevClick = nil
    if evClick in target:
      if mouseButtons != {}:
      # if prevClick.getId != target.getId:
        emit target.onClick(Enter, mouseButtons)
        # refresh(target)
        prevClick = target

  uxInputs.mouse.consumed = true
  uxInputs.keyboard.consumed = true