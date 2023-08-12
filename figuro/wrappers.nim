
import common/nodes/render
import common/nodes/transfer
import widget
# import runtime/msgpack_lite
import json, unicode

proc `%`*(x: Box): JsonNode {.borrow.}
proc `%`*(x: Position): JsonNode {.borrow.}
proc `%`*(x: UICoord): JsonNode {.borrow.}
proc `%`*(x: Rune): JsonNode =
  %($x)
proc `%`*(x: (UICoord,UICoord,UICoord,UICoord)): JsonNode =
  %([x[0], x[1], x[2], x[3]])
proc `%`*(x: set[Attributes]): JsonNode =
  %(x.toSeq())

var appMain {.compileTime.}: proc ()

proc appInit() =
  discard

proc appTick*(frameCount: int) =
  discard

proc appDraw*() =
  echo "app draw!"
  appMain()

# proc pack_type*[S](s: S, v: Position) =
#   s.pack(Vec2(v))

proc test*() = discard
proc getRoot*(): string =
  let nodes = root.copyInto()
  result = pretty(%*(nodes))

proc run*(init: proc() {.nimcall.},
          tick: proc(tick: int) {.nimcall.},
          draw: proc() {.nimcall.},
          getRoot: proc(): string {.nimcall.}
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

  setupRoot(appWidget)

  run(
    appInit,
    appTick,
    appDraw,
    getRoot
  )
