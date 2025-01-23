
import figuro/commons
import figuro/ui/apis
import figuro/widget
import sigils
import chronicles

export chronicles
export commons, apis, widget, sigils

when defined(compilervm) or defined(nimscript):
  import figuro/runtime/wrappers
  export wrappers
else:
  import figuro/runtime/runtimeNative
  export runtimeNative

when defined(macosx):
  {.passc: "-Wno-incompatible-function-pointer-types".}
