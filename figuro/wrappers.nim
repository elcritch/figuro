
import widget

proc startFiguro*[T: Figuro](
  widget: T,
  setup: proc() = nil,
  fullscreen = false,
  w: Positive = 1280,
  h: Positive = 800,
  pixelate = false,
  pixelScale = 1.0
) =
  discard