
import figuro/shared
import figuro/ui/apis
import figuro/widget
import sigils
import chronicles

export chronicles
export shared, apis, widget, sigils

when defined(compilervm) or defined(nimscript):
  import figuro/wrappers
  export wrappers
else:
  import figuro/execApps
  export execApps

when defined(macosx):
  {.passc: "-Wno-incompatible-function-pointer-types".}
