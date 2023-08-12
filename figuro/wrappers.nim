
import widget

var appMain {.compileTime.}: proc ()

proc appInit() =
  discard

proc appTick*(frameCount: int) =
  discard

proc appDraw*() =
  echo "app draw!"
  appMain()

proc test*() = discard

proc run*(init: proc() {.nimcall.},
          tick: proc(tick: int) {.nimcall.},
          draw: proc() {.nimcall.}
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

  let appWidget = T()

  appMain = proc() =
    draw(appWidget)

  run(
    appInit,
    appTick,
    appDraw,
  )
