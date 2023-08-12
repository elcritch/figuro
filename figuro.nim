
import figuro/shared
import figuro/ui/apis
import figuro/widget
import figuro/meta

export shared, apis, widget, meta

when defined(compilervm) or defined(nimscript):
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
else:
  import figuro/engine
  export engine

