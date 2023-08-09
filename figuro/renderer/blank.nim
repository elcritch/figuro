## Backend null is a dummy backend used for testing / dec gen
## Not a real backend will not draw anything

import common, internal, tables, times

var
  windowTitle, windowUrl: string
  values = newTable[string, string]()

proc draw*(node: Node) =
  ## Draws the node

proc postDrawChildren*(node: Node) =
  ## Turns off clip masks and such

proc openBrowser*(url: string) =
  ## Opens a URL in a browser
  discard

proc startFiguro*(
    draw: proc(),
    tick: proc() = nil,
    fullscreen = false,
    w: Positive = 1280,
    h: Positive = 800,
) =
  ## Starts fidget UI library
  drawMain = draw
  for i in 0 ..< 10:
    let startTime = epochTime()
    setupRoot()
    drawMain()
    echo "drawMain walk took: ", epochTime() - startTime, "ms"
  # dumpTree(root)

