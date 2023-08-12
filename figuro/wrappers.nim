
import widget

var appWidget: Figuro

proc appInit() =
  discard

proc appTick*(frameCount: int) =
  discard

proc appDraw*() =
  mixin draw
  draw(appWidget)

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

  run(
    appInit,
    appTick,
    appDraw,
  )