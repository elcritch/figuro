
import common/nodes/render
import common/nodes/transfer
import widget
import runtime/msgpack_lite
# import unicode
# import json, unicode

# proc `%`*(x: Box): JsonNode {.borrow.}
# proc `%`*(x: Position): JsonNode {.borrow.}
# proc `%`*(x: UICoord): JsonNode {.borrow.}
# proc `%`*(x: Rune): JsonNode =
#   %($x)
# proc `%`*(x: (UICoord,UICoord,UICoord,UICoord)): JsonNode =
#   %([x[0], x[1], x[2], x[3]])
# proc `%`*(x: set[Attributes]): JsonNode =
#   %(x.toSeq())


var
  appMain {.compileTime.}: proc ()
  appTicker {.compileTime.}: proc ()

proc appInit() =
  discard

proc appTick*(frameCount: int) =
  app.frameCount = frameCount
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
          tick: proc(tick: int) {.nimcall.},
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
