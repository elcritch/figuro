import std/locks
import std/sets
import pkg/threading/atomics
import pkg/sigils
import pkg/sigils/threads
import pkg/chronicles

import runtimeCore
import ../widget, ../commons
import ../ui/[core, layout]
import ../common/nodes/[transfer, uinodes, render]

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

when not defined(gcArc) and not defined(gcOrc) and not defined(nimdoc):
  {.error: "Figuro requires --gc:arc or --gc:orc".}

var timestamp = getMonoTime()

proc runFrameImpl(frame: AppFrame) {.slot, forbids: [RenderThreadEff].} =
  threadEffects:
    AppMainThread
  # Ticks
  let last = timestamp
  timestamp = getMonoTime()
  emit frame.root.doTick(timestamp, timestamp - last)

  # Events
  var input: AppInputs
  ## only process up to ~X events at a time
  var cnt = 4
  while frame.uxInputList.tryRecv(input) and cnt > 0:
    uxInputs = input
    computeEvents(frame)
    cnt.dec()

  # Main
  frame.root.diffIndex = 0
  if app.requestedFrame > 0:
    refresh(frame.root)
    app.requestedFrame.dec()

  if frame.redrawNodes.len() > 0:
    trace "Frame Redraw! "
    computeEvents(frame)
    let rn = move frame.redrawNodes
    frame.redrawNodes.clear()
    for node in rn:
      emit node.doDraw()
    debug "computeLayouts: ", node= frame.root.name
    computeLayouts(frame.root)
    computeScreenBox(nil, frame.root)
    var ru = RenderUpdate(n= frame.root.copyInto(), window= frame.window)
    let sent = frame.rendInputList.trySend(unsafeIsolate ensureMove ru)
    if not sent:
      debug "failed to send render update"
      app.requestedFrame.inc()


proc startFiguro*(frame: var AppFrame) {.forbids: [AppMainThreadEff].} =
  ## Starts Fidget UI library
  ## 
  threadEffects:
    RenderThread
  runForever(frame, AppFrame.runFrameImpl())
