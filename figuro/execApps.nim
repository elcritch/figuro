
import std/locks
import std/sets
import pkg/threading/atomics
import shared, ui/core
import common/nodes/transfer
import common/nodes/ui as ui
import common/nodes/render as render
import widget

import exec

when not compileOption("threads"):
  {.error: "This module requires --threads:on compilation flag".}

when not defined(gcArc) and not defined(gcOrc) and not defined(nimdoc):
  {.error: "Figuro requires --gc:arc or --gc:orc".}

proc runFrameImpl(frame: AppFrame) =
    # Ticks
    emit frame.root.doTick(app.tickCount, getMonoTime())

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
      computeEvents(frame)
      let rn = frame.redrawNodes
      for node in rn:
        emit node.doDraw()
      frame.redrawNodes.clear()
      computeLayout(frame.root)
      computeScreenBox(nil, frame.root)
      appFrames.withValue(frame, renderer):
        withLock(renderer.lock):
          renderer.nodes = frame.root.copyInto()
          renderer.updated.store true

exec.runFrame = runFrameImpl

proc startFiguro*(
    frame: AppFrame,
) =
  ## Starts Fidget UI library
  ## 

  # app.fullscreen = fullscreen
  # if not fullscreen:

  # let frame = newAppFrame(widget)
  run(frame)
