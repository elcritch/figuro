
import std/sets
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
    ## only process up to ~10 events at a time
    var cnt = 20
    while frame.uxInputList.tryRecv(input) and cnt > 0:
      uxInputs = input
      computeEvents(frame)
      cnt.dec()

    # Main
    frame.root.diffIndex = 0
    if app.requestedFrame > 0:
      frame.root.refresh(frame.root)
      app.requestedFrame.dec()

    if frame.redrawNodes.len() > 0:
      computeEvents(frame)
      let rn = frame.redrawNodes
      for node in rn:
        emit node.doDraw()
      frame.redrawNodes.clear()
      computeLayout(frame.root)
      computeScreenBox(nil, frame.root)
      discard exec.appFrames[frame].chan.trySend(
                frame.root.copyInto())

exec.runFrame = runFrameImpl

proc startFiguro*[T](
    widget: T,
    fullscreen = false,
    pixelate = false,
    pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 

  app.fullscreen = fullscreen
  if not fullscreen:
    app.windowSize = initBox(0.0, 0.0,
                             app.uiScale * app.width.float32,
                             app.uiScale * app.height.float32)

  let atlasStartSz = 1024 shl (app.uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"
  let renderer = setupRenderer(pixelate, pixelScale, atlasStartSz)
  let frame = newAppFrame(widget)
  frame.uxInputList = renderer.uxInputList
  run(renderer, frame)
