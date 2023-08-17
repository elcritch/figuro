
import common/nodes/render
import common/nodes/transfer
import widget

var
  appWidget* {.compileTime.}: FiguroApp
  appMain* {.compileTime.}: proc ()
  appTicker* {.compileTime.}: proc ()

proc appInit() =
  discard

proc appTick*(val: AppStatePartial): AppStatePartial =
  app.tickCount = val.tickCount
  app.uiScale = val.uiScale
  appTicker()
  result.requestedFrame = app.requestedFrame

proc appDraw*(): AppStatePartial =
  root.diffIndex = 0
  appMain()
  computeScreenBox(nil, root)
  result.requestedFrame = app.requestedFrame

proc getRoot*(): seq[Node] =
  result = root.copyInto()

proc getAppState*(): AppState =
  result = app

proc run*(init: proc() {.nimcall.},
          tick: proc(state: AppStatePartial): AppStatePartial {.nimcall.},
          draw: proc(): AppStatePartial {.nimcall.},
          getRoot: proc(): seq[Node] {.nimcall.},
          getAppState: proc(): AppState {.nimcall.}
          ) = discard

proc startFiguro*(
    widget: FiguroApp,
    setup: proc() = nil,
    fullscreen = false,
    pixelate = false,
    pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 

  app.fullscreen = fullscreen
  app.autoUiScale = true
  app.pixelRatio = pixelScale
  app.pixelate = pixelate

  echo "app: ", app.repr
  root = widget
  appWidget = widget

  appMain = proc() =
    emit appWidget.onDraw()
    emit appWidget.eventHover()

  appTicker = proc() =
    emit appWidget.onTick()

  setupRoot(appWidget)

  run(
    appInit,
    appTick,
    appDraw,
    getRoot,
    getAppState
  )
