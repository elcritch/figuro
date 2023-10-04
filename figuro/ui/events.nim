import commons

import core, utils

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var
  prevHovers {.runtimeVar.}: HashSet[Figuro]
  prevClicks {.runtimeVar.}: HashSet[Figuro]
  prevDrags {.runtimeVar.}: HashSet[Figuro]
  dragInitial {.runtimeVar.}: Position

proc mouseOverlaps*(node: Figuro, includeOffset = true): bool =
  ## Returns true if mouse overlaps the node node.
  var mpos = uxInputs.mouse.pos 
  if includeOffset:
    mpos += node.totalOffset 
  let act = 
    node.screenBox.w > 0'ui and
    node.screenBox.h > 0'ui 

  result = act and mpos.overlaps(node.screenBox)

template checkEvent[ET](node: typed, evt: ET, predicate: typed) =
  let res = predicate
  if evt in node.listens.events and res:
    result.incl(evt)
  if evt in node.listens.signals and res:
    result.incl(evt)

proc checkAnyEvents*(node: Figuro): EventFlags =
  ## Compute mouse events
  node.checkEvent(evKeyboardInput, uxInputs.keyboard.rune.isSome())
  node.checkEvent(evKeyPress, uxInputs.buttonPress - MouseButtons != {})
  node.checkEvent(evDrag, prevDrags.len() > 0)

  if node.mouseOverlaps():
    node.checkEvent(evClick, uxInputs.mouse.click())
    node.checkEvent(evPress, uxInputs.mouse.down())
    node.checkEvent(evRelease, uxInputs.mouse.release())
    node.checkEvent(evOverlapped, true)
    node.checkEvent(evHover, true)
    node.checkEvent(evScroll, uxInputs.mouse.wheelDelta.sum().float32.abs() > 0.0)
    node.checkEvent(evDrag, uxInputs.mouse.down())
    node.checkEvent(evDragEnd, prevDrags.len() > 0 and uxInputs.mouse.release())
  
  if rootWindow in node.attrs:
    node.checkEvent(evDragEnd, prevDrags.len() > 0 and uxInputs.mouse.release())


type
  EventsCapture* = object
    zlvl*: ZLevel
    flags*: EventFlags
    targets*: HashSet[Figuro]
    buttons*: UiButtonView

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

  for ek in EventKinds:
    let captured = EventsCapture(zlvl: node.zlevel,
                                  flags: matchingEvts * {ek},
                                  buttons: buttons[ek],
                                  targets: toHashSet([node]))

    if noClipContent notin node.attrs and
          result[ek].zlvl <= node.zlevel and
          not node.mouseOverlaps(false):
      ## this node clips events, so it must overlap child events, 
      ## e.g. ignore child captures if this node isn't also overlapping 
      result[ek] = captured
    elif ek == evHover and evHover in matchingEvts:
      result[ek].targets.incl(captured.targets)
      result[ek].targets.incl(result[ek].targets)
      result[ek].flags.incl(evHover)
    else:
      result[ek] = maxEvt(captured, result[ek])

    if node.mouseOverlaps(false) and node.parent != nil and
        result[ek].targets.anyIt(it.zlevel < node.zlevel):
      ## if a target node is a lower level, then ignore it
      result[ek] = captured
      let targets = result[ek].targets
      result[ek].targets.clear()
      for tgt in targets:
        if tgt.zlevel >= node.zlevel:
          result[ek].targets.incl(tgt)

  # echo "computeNodeEvents:result:post: ", result.mouse.flags, " :: ", result.mouse.target.uid

proc computeEvents*(node: Figuro) =
  ## mouse and gesture are handled separately as they can have separate
  ## node targets
  root.listens.signals.incl {evClick, evClickOut, evDragEnd}
  root.attrs.incl rootWindow

  if redrawNodes.len() == 0 and
      uxInputs.mouse.consumed and
      uxInputs.keyboard.rune.isNone and
      prevHovers.len == 0 and
      prevDrags.len == 0:
    return

  # printFiguros(node)
  var captured: CapturedEvents = computeNodeEvents(node)

  uxInputs.windowSize = Box.none

  # set mouse event flags in targets
  for ek in EventKinds:
    let evts = captured[ek]
    for target in evts.targets:
      for target in evts.targets:
        target.events.incl evts.flags

  # Mouse
  printNewEventInfo()

  # handle keyboard inputs
  let keyInput = captured[evKeyboardInput]
  if keyInput .targets.len() > 0 and
      evKeyboardInput in keyInput.flags and
      uxInputs.keyboard.rune.isSome:
    let rune = uxInputs.keyboard.rune.get()
    uxInputs.keyboard.rune = Rune.none

    # echo "keyboard input: ", " rune: `", $rune, "`", " tgts: ", $keys.targets
    for target in keyInput.targets:
      if rune.ord > 31 and rune.ord != 127: # No control and no 'del'
        emit target.doKeyInput(rune)

  ## handle keyboard presses
  block keyboardEvents:
    let keyPress = captured[evKeyPress]
    if keyPress.targets.len() > 0 and
        evKeyPress in keyPress.flags and
        uxInputs.buttonPress != {} and
        not uxInputs.keyboard.consumed:
      let pressed = uxInputs.buttonPress - MouseButtons
      let down = uxInputs.buttonDown - MouseButtons

      # echo "keyboard input: ", " pressed: `", $pressed, "`", " down: `", $down, "`", " tgts: ", $keyPress.targets
      for target in keyPress.targets:
        emit target.doKeyPress(pressed, down)

  ## handle scroll events
  block scrollEvents:
    let scroll = captured[evScroll]
    if scroll.targets.len() > 0 and
        not uxInputs.mouse.consumed:

      for target in scroll.targets:
        # echo "scroll input: ", $target.uid, " name: ", $target.name
        emit target.doScroll(uxInputs.mouse.wheelDelta)

  ## handle hover events
  block hoverEvents:
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

  ## handle click events
  block clickEvents:
    let click = captured[evClick]
    if click.targets.len() > 0 and evClick in click.flags:
      let clickTargets = click.targets
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

  ## handle drag events
  block dragEvents:
    let drags = captured[evDrag]
    if evDrag in drags.flags:
      let newDrags = drags.targets + prevDrags
      if prevDrags.len() == 0:
        dragInitial = uxInputs.mouse.pos
      # echo "drag:newTargets: ", drags.targets, " prev: ", prevDrags, " flg: ", drags.flags
      for target in newDrags:
        target.events.incl evDrag
        emit target.doDrag(Enter, dragInitial, uxInputs.mouse.pos)
        prevDrags.incl target

  block dragEndEvents:
    let dragens = captured[evDragEnd]
    if dragens.targets.len() > 0 and evDragEnd in dragens.flags:
      # echo "dragends: ", dragens.targets, " prev: ", prevDrags, " flg: ", dragens.flags
      for target in prevDrags:
        emit target.doDrag(Exit, dragInitial, uxInputs.mouse.pos)
      prevDrags.clear()
      for target in dragens.targets:
        # echo "dragends:tgt: ", target.getId
        if rootWindow notin target.attrs:
          target.events.excl evDragEnd
        emit target.doDrag(Exit, dragInitial, uxInputs.mouse.pos)

  uxInputs.buttonPress = {}
  uxInputs.buttonDown = {}
  uxInputs.buttonRelease = {}

  uxInputs.mouse.consumed = true
  uxInputs.keyboard.consumed = true
  uxInputs.mouse.wheelDelta = initPosition(0, 0)