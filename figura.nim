
import algorithm, chroma, bumpy
import std/[json, macros, tables]
import cssgrid

import figura/engine/[common, commonutils]

export chroma, common
export commonutils
export cssgrid

import pretty

when defined(js):
  import figura/htmlbackend
  export htmlbackend
elif defined(nullbackend):
  import figura/nullbackend
  export nullbackend
else:
  import figura/engine/openglbackend
  export openglbackend

