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
  node.zlevel = 0.ZLevel
  

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
    # Create Figuro.
    current = T.new()
    echo nd(), "create new node: ", id, " new: ", current.uid, " parent: ", parent.uid
    parent.children.add(current)
    # current.parent = parent
    refresh(current)
  else:
    # Reuse Figuro.
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

  current.uid = current.agentId
  current.parent = parent
  let name = $(id)
  current.name.setLen(0)
  discard current.name.tryAdd(name)
  current.kind = kind
  current.highlight = parent.highlight
  current.transparency = parent.transparency
  current.zlevel = parent.zlevel

  current.listens.events = {}

  nodeStack.add(current)
  inc parent.diffIndex
  current.diffIndex = 0

  connect(current, doDraw, current, Figuro.clearDraw())
  connect(current, doDraw, current, typeof(current).draw())
  connect(current, doDraw, current, Figuro.handlePostDraw())
  connect(current, doClick, current, typeof(current).clicked())
  emit current.doDraw()

proc postNode*(current: var Figuro) =
  if not current.postDraw.isNil:
    current.postDraw(current)

  current.removeExtraChildren()
  nodeDepth.dec()

import utils, macros

macro node*(kind: NodeKind, args: varargs[untyped]): untyped =
  ## Base template for node, frame, rectangle...
  let widget = ident("Figuro")
  let wargs = args.parseWidgetArgs()
  result = widget.generateBodies(kind, wargs)

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
  if evt in node.listens.events and res:
    result.incl(evt)
  if evt in node.listens.signals and res:
    result.incl(evt)

proc checkAnyEvents*(node: Figuro): EventFlags =
  ## Compute mouse events
  node.checkEvent(evKeyboardInput, true)

  if node.mouseOverlaps():
    node.checkEvent(evClick, uxInputs.mouse.click())
    node.checkEvent(evPress, uxInputs.mouse.down())
    node.checkEvent(evRelease, uxInputs.mouse.release())
    node.checkEvent(evOverlapped, true)
    node.checkEvent(evHover, true)

type
  EventsCapture* = object
    zlvl*: ZLevel
    flags*: EventFlags
    targets*: HashSet[Figuro]
    buttons*: UiButtonView
    rune*: Rune

  CapturedEvents* = array[EventKinds, EventsCapture]

proc maxEvt(a, b: EventsCapture): EventsCapture =
  if b.zlvl >= a.zlvl and b.flags != {}: b
  else: a

proc consumeMouseButtons(matchedEvents: EventFlags): array[EventKinds, UiButtonView] =
  ## Consume mouse buttons
  ## 
  if evPress in matchedEvents:
    result[evPress] = uxInputs.buttonPress * MouseButtons
    uxInputs.buttonPress.excl MouseButtons
  if evDown in matchedEvents:
    result[evDown] = uxInputs.buttonDown * MouseButtons
    uxInputs.buttonDown.excl MouseButtons
  if evRelease in matchedEvents:
    result[evRelease] = uxInputs.buttonRelease * MouseButtons
    uxInputs.buttonRelease.excl MouseButtons
  if evClick in matchedEvents:
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
  
  if uxInputs.windowSize.isSome and rxWindowResize in node.attrs:
    refresh(node)

  for n in node.children.reverse:
    let child = computeNodeEvents(n)
    for ek in EventKinds:
      result[ek] = maxEvt(result[ek], child[ek])

  let
    matchingEvts = node.checkAnyEvents()
    buttons = matchingEvts.consumeMouseButtons()
    nodeOvelaps = node.mouseOverlaps()

  for ek in EventKinds:
    let captured = EventsCapture(zlvl: node.zlevel,
                                  flags: matchingEvts * {ek},
                                  buttons: buttons[ek],
                                  rune: uxInputs.keyboard.rune,
                                  targets: toHashSet([node]))

    if clipContent in node.attrs and
          result[ek].zlvl <= node.zlevel and
          not nodeOvelaps:
      # this node clips events, so it must overlap child events, 
      # e.g. ignore child captures if this node isn't also overlapping 
      result[ek] = captured
    elif ek == evHover and evHover in matchingEvts:
      result[ek].targets.incl(captured.targets)
      result[ek].targets.incl(result[ek].targets)
      result[ek].flags.incl(evHover)
    else:
      result[ek] = maxEvt(captured, result[ek])
      # result.gesture = max(captured.gesture, result.gesture)

    if nodeOvelaps and node.parent != nil and
        result[ek].targets.anyIt(it.zlevel < node.zlevel):
      # if a target node is a lower level, then ignore it
      result[ek] = captured
      let targets = result[ek].targets
      result[ek].targets.clear()
      for tgt in targets:
        if tgt.zlevel >= node.zlevel:
          result[ek].targets.incl(tgt)

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

  # printFiguros(node)
  var captured: CapturedEvents = computeNodeEvents(node)

  uxInputs.windowSize = none Position

  # set mouse event flags in targets
  for ek in EventKinds:
    let evts = captured[ek]
    for target in evts.targets:
      for target in evts.targets:
        target.events.incl evts.flags

  # Mouse
  printNewEventInfo()

  if captured[evHover].targets != prevHovers:
    let hoverTargets = captured[evHover].targets
    let newHovers = hoverTargets - prevHovers
    let delHovers = prevHovers - hoverTargets

    for target in newHovers:
      target.events.incl evHover
      emit target.doHover(Enter)
      target.refresh()
      prevHovers.incl target

    for target in delHovers:
      target.events.excl evHover
      emit target.doHover(Exit)
      target.refresh()
      prevHovers.excl target

  let click = captured[evClick]
  if click.targets.len() > 0 and evClick in click.flags:
    let clickTargets = captured[evClick].targets
    let newClicks = clickTargets
    let delClicks = prevClicks - clickTargets

    for target in delClicks:
        target.events.excl evClick
        emit target.doClick(Exit, click.buttons)
        prevClicks.excl target

    for target in newClicks:
        target.events.incl evClick
        emit target.doClick(Enter, click.buttons)
        prevClicks.incl target

  uxInputs.buttonPress.excl MouseButtons
  uxInputs.buttonDown.excl MouseButtons
  uxInputs.buttonRelease.excl MouseButtons

  uxInputs.mouse.consumed = true
  uxInputs.keyboard.consumed = true

var gridChildren: seq[Figuro]

proc checkParent(node: Figuro) =
  if node.parent.isNil:
    raise newException(FiguroError, "cannot calculate exception: current: " & $node.getId & " parent: " & $node.parent.getId)

template calcBasicConstraintImpl(
    node: Figuro,
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
          node.checkParent()
          res = frac.UICoord * node.parent.box.f
        UiPerc(perc):
          node.checkParent()
          let ppval = when astToStr(f) == "x": node.parent.box.w
                      elif astToStr(f) == "y": node.parent.box.h
                      else: node.parent.box.f
          res = perc.UICoord / 100.0.UICoord * ppval
      res
  
  let csValue = when astToStr(f) in ["w", "h"]: node.cxSize[dir] 
                else: node.cxOffset[dir]
  match csValue:
    UiAuto():
      when astToStr(f) in ["w", "h"]:
        node.checkParent()
        node.box.f = node.parent.box.f
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

proc calcBasicConstraint(node: Figuro, dir: static GridDir, isXY: static bool) =
  when isXY == true and dir == dcol: 
    calcBasicConstraintImpl(node, dir, x)
  elif isXY == true and dir == drow: 
    calcBasicConstraintImpl(node, dir, y)
  elif isXY == false and dir == dcol: 
    calcBasicConstraintImpl(node, dir, w)
  elif isXY == false and dir == drow: 
    calcBasicConstraintImpl(node, dir, h)

proc computeLayout*(node: Figuro) =
  ## Computes constraints and auto-layout.
  
  # # simple constraints
  if node.gridItem.isNil and node.parent != nil:
    # assert node.parent != nil, "check parent isn't nil: " & $node.parent.getId & " curr: " & $node.getId
    calcBasicConstraint(node, dcol, true)
    calcBasicConstraint(node, drow, true)
    calcBasicConstraint(node, dcol, false)
    calcBasicConstraint(node, drow, false)

  # css grid impl
  if not node.gridTemplate.isNil:
    # echo "calc grid!"
    
    gridChildren.setLen(0)
    for n in node.children:
      # if n.layoutAlign != laIgnore:
      gridChildren.add(n)
    node.gridTemplate.computeNodeLayout(node, gridChildren)

    for n in node.children:
      computeLayout(n)

    return

  for n in node.children:
    computeLayout(n)

  # if node.layoutAlign == laIgnore:
  #   return

  # Constraints code.
  # case node.constraintsVertical:
  #   of cMin: discard
  #   of cMax:
  #     let rightSpace = parent.orgBox.w - node.box.x
  #     # echo "rightSpace : ", rightSpace  
  #     node.box.x = parent.box.w - rightSpace
  #   of cScale:
  #     let xScale = parent.box.w / parent.orgBox.w
  #     # echo "xScale: ", xScale 
  #     node.box.x *= xScale
  #     node.box.w *= xScale
  #   of cStretch:
  #     let xDiff = parent.box.w - parent.orgBox.w
  #     # echo "xDiff: ", xDiff   
  #     node.box.w += xDiff
  #   of cCenter:
  #     let offset = floor((node.orgBox.w - parent.orgBox.w) / 2.0'ui + node.orgBox.x)
  #     # echo "offset: ", offset   
  #     node.box.x = floor((parent.box.w - node.box.w) / 2.0'ui) + offset

  # case node.constraintsHorizontal:
  #   of cMin: discard
  #   of cMax:
  #     let bottomSpace = parent.orgBox.h - node.box.y
  #     # echo "bottomSpace  : ", bottomSpace   
  #     node.box.y = parent.box.h - bottomSpace
  #   of cScale:
  #     let yScale = parent.box.h / parent.orgBox.h
  #     # echo "yScale: ", yScale
  #     node.box.y *= yScale
  #     node.box.h *= yScale
  #   of cStretch:
  #     let yDiff = parent.box.h - parent.orgBox.h
  #     # echo "yDiff: ", yDiff 
  #     node.box.h += yDiff
  #   of cCenter:
  #     let offset = floor((node.orgBox.h - parent.orgBox.h) / 2.0'ui + node.orgBox.y)
  #     node.box.y = floor((parent.box.h - node.box.h) / 2.0'ui) + offset

  # # Typeset text
  # if node.kind == nkText:
  #   computeTextLayout(node)
  #   case node.textStyle.autoResize:
  #     of tsNone:
  #       # Fixed sized text node.
  #       discard
  #     of tsHeight:
  #       # Text will grow down.
  #       node.box.h = node.textLayoutHeight
  #     of tsWidthAndHeight:
  #       # Text will grow down and wide.
  #       node.box.w = node.textLayoutWidth
  #       node.box.h = node.textLayoutHeight
  #   # print "layout:nkText: ", node.id, node.box

  # template compAutoLayoutNorm(field, fieldSz, padding: untyped;
  #                             orth, orthSz, orthPadding: untyped) =
  #   # echo "layoutMode : ", node.layoutMode 
  #   if node.counterAxisSizingMode == csAuto:
  #     # Resize to fit elements tightly.
  #     var maxOrth = 0.0'ui
  #     for n in node.nodes:
  #       if n.layoutAlign != laStretch:
  #         maxOrth = max(maxOrth, n.box.`orthSz`)
  #     node.box.`orthSz` = maxOrth  + node.`orthPadding` * 2'ui

  #   var at = 0.0'ui
  #   at += node.`padding`
  #   for i, n in node.nodes.pairs:
  #     if n.layoutAlign == laIgnore:
  #       continue
  #     if i > 0:
  #       at += node.itemSpacing

  #     n.box.`field` = at

  #     case n.layoutAlign:
  #       of laMin:
  #         n.box.`orth` = node.`orthPadding`
  #       of laCenter:
  #         n.box.`orth` = node.box.`orthSz`/2'ui - n.box.`orthSz`/2'ui
  #       of laMax:
  #         n.box.`orth` = node.box.`orthSz` - n.box.`orthSz` - node.`orthPadding`
  #       of laStretch:
  #         n.box.`orth` = node.`orthPadding`
  #         n.box.`orthSz` = node.box.`orthSz` - node.`orthPadding` * 2'ui
  #         # Redo the layout for child node.
  #         computeLayout(node, n)
  #       of laIgnore:
  #         continue
  #     at += n.box.`fieldSz`
  #   at += node.`padding`
  #   node.box.`fieldSz` = at

  # # Auto-layout code.
  # if node.layoutMode == lmVertical:
  #   compAutoLayoutNorm(y, h, verticalPadding, x, w, horizontalPadding)

  # if node.layoutMode == lmHorizontal:
  #   # echo "layoutMode : ", node.layoutMode 
  #   compAutoLayoutNorm(x, w, horizontalPadding, y, h, verticalPadding)
