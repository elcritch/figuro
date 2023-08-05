

when defined(js):
  import figuro/htmlbackend
  export htmlbackend
elif defined(blank):
  import engine/blank
  export blank
else:
  import engine/opengl
  export opengl

import common, internal

proc startFidget*(
    draw: proc() {.nimcall.} = nil,
    tick: proc() {.nimcall.} = nil,
    load: proc() {.nimcall.} = nil,
    setup: proc() = nil,
    fullscreen = false,
    w: Positive = 1280,
    h: Positive = 800,
    pixelate = false,
    pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 
  common.fullscreen = fullscreen
  
  if not fullscreen:
    windowSize = vec2(uiScale * w.float32, uiScale * h.float32)
  drawMain = draw
  tickMain = tick
  loadMain = load

  let atlasStartSz = 1024 shl (uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"

  setupWindow(pixelate, pixelScale, atlasStartSz)
  mouse.pixelScale = pixelScale

  if not setup.isNil: setup()
  runRenderer()