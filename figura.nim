
import algorithm, chroma, bumpy
import std/[json, macros, tables]
import cssgrid

import figura/[common, commonutils]
import figura/widgets/apis

export chroma, cssgrid, cssgrid
export common, commonutils

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

