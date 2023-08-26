
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

proc startFiguro*(
    widget: Figuro,
    setup: proc() = nil,
    fullscreen = false,
    pixelate = false,
    pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 

  # appWidget = widget
  app.fullscreen = fullscreen

  if not fullscreen:
    app.windowSize = Position vec2(app.uiScale * app.width.float32,
                                   app.uiScale * app.height.float32)

  root = widget
  redrawNodes = initOrderedSet[Figuro]()
  refresh(root)

  proc appTick() =
    emit root.onTick()

  proc appEvent() =
    computeEvents(root)

  proc appLoad() =
    emit root.onLoad()
  
  proc appMain() =
    # mixin draw
    root.diffIndex = 0
    if not uxInputs.mouse.consumed:
      uxInputs.mouse.consumed = true
    if redrawNodes.len() > 0:
      # echo "appMain:redrawNodes:len: ", redrawNodes.len()
      let rn = redrawNodes
      for node in rn:
        # echo "appMain:redraw:id: ", node.uid
        emit node.onDraw()
      redrawNodes.clear()
    computeScreenBox(nil, root)
    sendRoot(root.copyInto())

  setupRoot(root)

  loadMain = appLoad
  tickMain = appTick
  eventMain = appEvent
  mainApp = appMain

  if mainApp.isNil:
    raise newException(AssertionDefect, "mainApp cannot be nil")
  if eventMain.isNil:
    raise newException(AssertionDefect, "eventMain cannot be nil")
  if tickMain.isNil:
    tickMain = proc () = discard
  if loadMain.isNil:
    loadMain = proc () = discard

  let atlasStartSz = 1024 shl (app.uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"

  let renderer = setupRenderer(pixelate, pixelScale, atlasStartSz)

  if not setup.isNil: setup()
  renderer.run()
