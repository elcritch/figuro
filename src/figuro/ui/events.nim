import pkg/sigils
import ../commons

import core, utils

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

proc defaultKeyConfigs(): array[ModifierKey, set[UiKey]] =
  result[KNone] = {}
  result[KMeta] =
    when defined(macosx):
      {KeyLeftSuper, KeyRightSuper}
    else:
      {KeyLeftControl, KeyRightControl}
  result[KAlt] = {KeyLeftAlt, KeyRightAlt}
  result[KShift] = {KeyLeftShift, KeyRightShift}
  result[KMenu] = {KeyMenu}

var keyConfig* {.runtimeVar.}: array[ModifierKey, set[UiKey]] = defaultKeyConfigs()
var uxInputs* {.runtimeVar.} = AppInputs()

proc matches(keys: set[UiKey], commands: ModifierKey): bool =
  let ck = keys * ModifierButtons
  if ck == {} and keyConfig[commands] == {}:
    result = true
  else:
    result = ck < keyConfig[commands]
  echo "matches: ", " commands: ", $commands, " ck: ", $ck, " keyConfig: ", $keyConfig[commands], " result: ", result

proc matches*(keys: set[UiKey], commands: set[ModifierKey]): bool =
  let ck = keys * ModifierButtons
  var modKeys: set[UiKey] = {}
  for cmd in commands:
    modKeys.incl keyConfig[cmd]

  if KNone in commands:
    result = ck == {}
  else:
    result = ck < modKeys

var
  prevHovers {.runtimeVar.}: HashSet[Figuro]
  prevClicks {.runtimeVar.}: HashSet[Figuro]
  prevDrags {.runtimeVar.}: HashSet[Figuro]
  prevPressed {.runtimeVar.}: HashSet[Figuro]
  dragInitial {.runtimeVar.}: Position
  dragReleased {.runtimeVar.}: bool

proc mouseOverlaps*(node: Figuro, includeOffset = true): bool =
  ## Returns true if mouse overlaps the node node.
  var mpos = uxInputs.mouse.pos
  if includeOffset:
    mpos -= node.offset
  let act = node.screenBox.w > 0'ui and node.screenBox.h > 0'ui

  result = act and mpos.overlaps(node.screenBox)

proc checkAnyEvents*(node: Figuro): EventFlags =
  ## Compute mouse events
  template checkEvent[ET](node: typed, evt: ET, predicate: typed) =
    let res = predicate
    if evt in node.listens.events and res:
      result.incl(evt)
    if evt in node.listens.signals and res:
      result.incl(evt)

  node.checkEvent(evKeyboardInput, uxInputs.keyboard.rune.isSome())
  node.checkEvent(evKeyPress, uxInputs.keyPress != {})
  node.checkEvent(evDrag, prevDrags.len() > 0)

  if node.mouseOverlaps():
    node.checkEvent(evClickInit, uxInputs.buttonDown != {})
    when defined(clickOnDown):
      # click on mouse down
      node.checkEvent(evClickDone, uxInputs.buttonDown != {})
    else:
      # click on mouse button release
      node.checkEvent(evClickDone, uxInputs.buttonRelease != {})
    node.checkEvent(evPress, uxInputs.buttonDown != {})
    node.checkEvent(evRelease, uxInputs.buttonRelease != {})
    node.checkEvent(evOverlapped, true)
    node.checkEvent(evHover, true)
    node.checkEvent(evScroll, uxInputs.mouse.wheelDelta.sum().float32.abs() > 0.0)
    node.checkEvent(evDrag, uxInputs.buttonDown != {})
    node.checkEvent(evDragEnd, dragReleased)

  if NfRootWindow in node.flags:
    node.checkEvent(evDragEnd, dragReleased)

type
  EventsCapture* = object
    zlvl*: ZLevel
    flags*: EventFlags
    mouse*: set[UiMouse]
    keys*: set[UiKey]
    targets*: HashSet[Figuro]

  CapturedEvents* = array[EventKinds, EventsCapture]

proc `$`*(capture: EventsCapture): string =
  result = "EventsCapture("
  result &= $capture.zlvl & ","
  result &= $capture.flags & ","
  result &= $capture.mouse & ","
  result &= $capture.keys & ","
  result &= $capture.targets & ")"

proc maxEvt(a, b: EventsCapture): EventsCapture =
  if b.zlvl >= a.zlvl and b.flags != {}: b else: a

proc consumeMouseButtons(matchedEvents: EventFlags): array[EventKinds, set[UiMouse]] =
  ## Consume mouse buttons
  ##
  if evPress in matchedEvents:
    result[evPress] = uxInputs.buttonPress
    uxInputs.buttonPress = {}
  if evDown in matchedEvents:
    result[evDown] = uxInputs.buttonDown
    uxInputs.buttonDown = {}
  if evRelease in matchedEvents:
    result[evRelease] = uxInputs.buttonRelease
  if evClickInit in matchedEvents:
    result[evDown] = uxInputs.buttonDown
    result[evPress] = uxInputs.buttonPress
    result[evClickInit] = result[evPress]
  if evClickDone in matchedEvents:
    result[evDown] = uxInputs.buttonDown
    result[evRelease] = uxInputs.buttonRelease
    result[evClickDone] = result[evRelease]

proc consumeKeyButtons(matchedEvents: EventFlags): array[EventKinds, set[UiKey]] =
  ## Consume key buttons
  ##
  if evKeyPress in matchedEvents:
    result[evKeyPress] = uxInputs.keyPress
    # uxInputs.keyPress = {}

proc computeNodeEvents*(node: Figuro): CapturedEvents =
  ## Compute mouse events
  ##

  # if uxInputs.windowSize.isSome and rxWindowResize in node.attrs:
  #   refresh(node)

  for n in node.children:
    if Hidden in n.userAttrs:
      continue

    let child = computeNodeEvents(n)
    for ek in EventKinds:
      result[ek] = maxEvt(result[ek], child[ek])

  let
    matchingEvts = node.checkAnyEvents()
    mouseButtons = matchingEvts.consumeMouseButtons()
    keyButtons = matchingEvts.consumeKeyButtons()

  for ek in EventKinds:
    let captured = EventsCapture(
      zlvl: node.zlevel,
      flags: matchingEvts * {ek},
      mouse: mouseButtons[ek],
      keys: keyButtons[ek],
      targets: toHashSet([node]),
    )

    if NfClipContent in node.flags and result[ek].zlvl <= node.zlevel and ek != evDrag and
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

    if node.mouseOverlaps(false) and not node.parent.isNil() and
        result[ek].targets.anyIt(it.zlevel < node.zlevel):
      ## if a target node is a lower level, then ignore it
      result[ek] = captured
      let targets = result[ek].targets
      result[ek].targets.clear()
      for tgt in targets:
        if tgt.zlevel >= node.zlevel:
          result[ek].targets.incl(tgt)

  # echo "computeNodeEvents:result:post: ", result.mouse.flags, " :: ", result.mouse.target.uid

proc computeEvents*(frame: AppFrame) =
  ## mouse and gesture are handled separately as they can have separate
  ## node targets
  ##
  ## It'd be nice to re-write this whole design. It sorta evolved
  ## from previous setup which was more immediate mode based.
  ## There may be ways to simplify this by moving to a more
  ## event-object based design. This is already sorta done
  ## now that each evKind has it's own target list, but the
  ## `for ek in EventKinds` still persists since it'd require
  ## refactoring this all. :/
  ##
  ## However, first tests would need to be written to ensure the
  ## behavior is kept. Events like drag, hover, and clicks all
  ## behave differently.
  frame.root.listens.signals.incl {evClickInit, evClickDone, evDragEnd}
  frame.root.flags.incl NfRootWindow

  if frame.redrawNodes.len() == 0 and uxInputs.mouse.consumed and
      uxInputs.keyboard.rune.isNone and prevHovers.len == 0 and prevDrags.len == 0:
    return

  # printFiguros(node)
  dragReleased = prevDrags.len() > 0 and uxInputs.release()

  var captured: CapturedEvents = computeNodeEvents(frame.root)

  if uxInputs.window.isSome():
    frame.windowInfo = uxInputs.window.get()
    uxInputs.window = WindowInfo.none
    # debug "events: window size: ", frame= frame.window.box, scaled= frame.window.box.wh.scaled()

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
  if keyInput.targets.len() > 0 and evKeyboardInput in keyInput.flags and
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
    if keyPress.targets.len() > 0 and evKeyPress in keyPress.flags and
        uxInputs.keyPress != {} and not uxInputs.keyboard.consumed:
      let pressed = uxInputs.keyPress
      let down = uxInputs.keyDown

      # echo "keyboard input: ", " pressed: `", $pressed, "`", " down: `", $down, "`", " tgts: ", $keyPress.targets
      for target in keyPress.targets:
        emit target.doKeyPress(pressed, down)

  ## handle scroll events
  block scrollEvents:
    let scroll = captured[evScroll]
    if scroll.targets.len() > 0 and not uxInputs.mouse.consumed:
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
        emit target.doHover(Init)
        refresh(target)
        prevHovers.incl target

      for target in delHovers:
        target.events.excl evHover
        emit target.doHover(Exit)
        refresh(target)
        prevHovers.excl target


  block clickEvents:
    let clickInit = captured[evClickInit]
    if clickInit.targets.len() > 0 and evClickInit in clickInit.flags:
      let clickTargets = clickInit.targets
      let newClicks = clickTargets
      let delClicks = prevClicks - clickTargets
      let pressed = uxInputs.buttonPress
      let down = uxInputs.buttonDown

      for target in newClicks:
        target.events.incl evClickDone
        emit target.doMouseClick(Init, down)
        prevClicks.incl target

    let click = captured[evClickDone]
    if click.targets.len() > 0 and evClickDone in click.flags:
      let clickTargets = click.targets
      let newClicks = clickTargets
      let delClicks = prevClicks - clickTargets
      # echo "click.buttons: ", click.buttons
      # echo "buttonRelease: ", uxInputs.buttonRelease
      # echo "buttonPress: ", uxInputs.buttonPress
      # echo "buttonDown: ", uxInputs.buttonPress

      for target in delClicks:
        target.events.excl evClickDone
        emit target.doMouseClick(Exit, click.mouse)
        prevClicks.excl target

      for target in newClicks:
        target.events.incl evClickDone
        emit target.doMouseClick(Done, click.mouse)
        if MouseLeft in click.mouse:
          emit target.doSingleClick()
        if DoubleClick in click.mouse:
          emit target.doDoubleClick()
        if MouseRight in click.mouse:
          emit target.doRightClick()
        if TripleClick in click.mouse:
          emit target.doTripleClick()
        prevClicks.incl target

  ## handle drag events
  ## Note: fixme? not sure but drags events are tricky
  ## do we want to target multiple nodes?
  var dragSource: Figuro = nil
  block dragEvents:
    let drags = captured[evDrag]
    if evDrag in drags.flags:
      let newDrags = drags.targets - prevDrags
      if prevDrags.len() == 0:
        dragInitial = uxInputs.mouse.pos
      # echo "drag:newTargets: ", drags.targets, " prev: ", prevDrags, " flg: ", drags.flags
      for target in newDrags:
        target.events.incl evDrag
        if mouseOverlaps(target, false):
          dragSource = target
          emit target.doDrag(Init, dragInitial, uxInputs.mouse.pos, true, dragSource)
        prevDrags.incl target

      for target in prevDrags:
        emit target.doDrag(Done, dragInitial, uxInputs.mouse.pos, mouseOverlaps(target, false), dragSource)

  block dragEndEvents:
    let dragens = captured[evDragEnd]
    if dragens.targets.len() > 0 and evDragEnd in dragens.flags:
      # echo "dragends: ", dragens.targets, " prev: ", prevDrags, " flg: ", dragens.flags
      let delClicks = prevDrags
      for target in delClicks:
          emit target.doDrag(Exit, dragInitial, uxInputs.mouse.pos, mouseOverlaps(target, false), dragSource)
      prevDrags.clear()
      for target in dragens.targets:
        # echo "dragends:tgt: ", target.getId
        # if NfRootWindow notin target.flags: target.events.excl evDragEnd
        emit target.doDragDrop(Done, dragInitial, uxInputs.mouse.pos, mouseOverlaps(target, false), dragSource)
      dragSource = nil

  uxInputs.buttonPress = {}
  uxInputs.buttonDown = {}
  uxInputs.buttonRelease = {}

  uxInputs.mouse.consumed = true
  uxInputs.keyboard.consumed = true
  uxInputs.mouse.wheelDelta = initPosition(0, 0)
