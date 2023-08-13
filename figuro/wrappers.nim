
import common/nodes/render
import common/nodes/transfer
import widget
import runtime/msgpack_lite

var
  appMain {.compileTime.}: proc ()
  appTicker {.compileTime.}: proc ()

proc appInit() =
  discard

proc appTick*(val: AppStatePartial) =
  app.frameCount = val.frameCount
  app.uiScale = val.uiScale
  appTicker()

proc appDraw*(): int =
  root.diffIndex = 0
  appMain()
  computeScreenBox(nil, root)
  result = app.requestedFrame

proc getRoot*(): seq[Node] =
  result = root.copyInto()

proc getAppState*(): AppState =
  result = app

proc run*(init: proc() {.nimcall.},
          tick: proc(state: AppStatePartial) {.nimcall.},
          draw: proc(): int {.nimcall.},
          getRoot: proc(): seq[Node] {.nimcall.},
          getAppState: proc(): AppState {.nimcall.}
          ) = discard

proc startFiguro*[T: Figuro](
  widget: typedesc[T],
  setup: proc() = nil,
  fullscreen = false,
  w: Positive = 1280,
  h: Positive = 800,
  pixelate = false,
  pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 
  mixin draw
  mixin tick
  mixin load

  app.fullscreen = fullscreen
  app.autoUiScale = true
  app.width = w
  app.height = h
  app.pixelRatio = pixelScale
  app.pixelate = pixelate

  echo "app: ", app.repr
  var appWidget = T()

  appMain = proc() =
    draw(appWidget)
  appTicker = proc() =
    tick(appWidget)

  setupRoot(appWidget)

  run(
    appInit,
    appTick,
    appDraw,
    getRoot,
    getAppState
  )
