
import figuro/commons
import figuro/ui/apis
import figuro/widget
import sigils
import sigils/reactive
import chronicles

export chronicles
export commons, apis, widget, sigils, reactive

when defined(compilervm) or defined(nimscript):
  import figuro/runtime/wrappers
  export wrappers
else:
  import figuro/runtime/runtimeNative
  export runtimeNative

when defined(macosx):
  {.passc: "-Wno-incompatible-function-pointer-types".}
