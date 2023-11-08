
import boxy, opengl, windy

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("mask", readImage("vendor/boxy/examples/data/mask.png"))
bxy.addImage("greece", readImage("vendor/boxy/examples/data/greece.png"))

var frame: int

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(0, 0, 0, 1))

  # Draw some background image.
  bxy.saveTransform()
  bxy.translate(window.size.vec2 / 2)
  bxy.scale(1.2 + 0.2 * sin(frame.float32/100))
  bxy.drawImage("greece", center = vec2(0, 0), angle = 0)
  bxy.restoreTransform()

  # Draw the mask.
  bxy.pushLayer()
  bxy.drawImage(
    "mask",
    center = window.size.vec2 / 2,
    angle = 0,
    tint = color(1, 0, 0, 1)
  )
  bxy.popLayer(blendMode = MaskBlend)

  # End this frame, flushing the draw commands.
  bxy.endFrame()

  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()