
import widget

var appWidget: Figuro


proc appInit() =
  discard

proc appRender*() =
  mixin draw
  draw(appWidget)

proc run*(init: proc(){.nimcall.},
          update: proc(_: float32){.nimcall.},
          draw: proc(){.nimcall.}
          ) = discard

proc startFiguro*[T: Figuro](
  widget: T,
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
  )