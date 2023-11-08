
import boxy, opengl, windy

let
  rhino = readImage("vendor/boxy/examples/data/rhino.png")

var i: int
proc display(window: Window, bxy: Boxy) =
  makeContextCurrent(window)
  bxy.beginFrame(window.size)
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(1, 1, 1, 1))
  bxy.drawImage("rhino", vec2((i mod window.size.x).float32, 0))
  bxy.endFrame()
  window.swapBuffers()
  inc i

let
  window1 = newWindow("Windy1 + Boxy", ivec2(1280, 800))
  window2 = newWindow("Windy2 + Boxy", ivec2(1280, 800))

var
  dirty1: bool
  dirty2: bool

makeContextCurrent(window1)
loadExtensions()

let bxy1 = newBoxy()
bxy1.addImage("rhino", rhino)

makeContextCurrent(window2)
loadExtensions()

let bxy2 = newBoxy()
bxy2.addImage("rhino", rhino)

window1.onFrame = proc() =
  if dirty1:
    dirty1 = false
    display(window1, bxy1)

window2.onFrame = proc() =
  if dirty2:
    dirty2 = false
    display(window2, bxy2)

window1.onMouseMove = proc() =
  echo "move 1", window1.mouseDelta
  dirty1 = true

window2.onMouseMove = proc() =
  echo "move 2", window2.mouseDelta
  dirty2 = true

while not window1.closeRequested and not window2.closeRequested:
  pollEvents()