
import algorithm, chroma, bumpy
import std/[json, macros, tables]
import cssgrid

import figuro/[common, commonutils]
import figuro/widgets/apis

export chroma, cssgrid, cssgrid
export common, commonutils, apis

import pretty

when defined(js):
  import figuro/htmlbackend
  export htmlbackend
elif defined(nullbackend):
  import figuro/nullbackend
  export nullbackend
else:
  import figuro/engine/openglbackend
  export openglbackend

