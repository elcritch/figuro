
import common/nodes/render
import common/nodes/transfer
import widget

var
  appWidget* {.compileTime.}: FiguroApp
  mainApp* {.compileTime.}: proc ()
  appTicker* {.compileTime.}: proc ()

proc appInit() =
  discard

proc appTick*(val: AppStatePartial): AppStatePartial =
  app.tickCount = val.tickCount
  app.uiScale = val.uiScale
  appTicker()
  result.requestedFrame = app.requestedFrame

proc appEvent*(uxi: AppInputs) =
  discard

proc appDraw*(): AppStatePartial =
  root.diffIndex = 0
  mainApp()
  computeScreenBox(nil, root)
  result.requestedFrame = app.requestedFrame

proc getRoot*(): seq[Node] =
  result = root.copyInto()

proc getAppState*(): AppState =
  result = app

proc run*(init: proc() {.nimcall.},
          tick: proc(state: AppStatePartial): AppStatePartial {.nimcall.},
          event: proc(inputs: AppInputs) {.nimcall.},
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

  mainApp = proc() =
    emit appWidget.onDraw()
    # emit appWidget.onHover()
    discard

  appTicker = proc() =
    emit appWidget.onTick()

  setupRoot(appWidget)

  run(
    appInit,
    appTick,
    appEvent,
    appDraw,
    getRoot,
    getAppState
  )
