
import pixie

let radius = 50
let offset3 = vec2(5, 10)
let spread = 10.0
let blur = 10.0
let adj = max(offset3.x.abs().int, offset3.y.abs().int) + 1*spread.int
let sz = 2*radius + 2*adj

let circle = newImage(sz, sz)
let ctx3 = newContext(circle)
ctx3.fillStyle = rgba(255, 255, 255, 255)
ctx3.circle(radius.float32 + adj.float32, radius.float32 + adj.float32, radius.float32)
ctx3.fill()

let shadow3 = circle.shadow(
  offset = offset3,
  spread = spread,
  blur = blur,
  color = rgba(0, 0, 0, 200)
)

let image3 = newImage(sz, sz)
image3.fill(rgba(255, 255, 255, 255))
image3.draw(shadow3)
image3.draw(circle)
image3.writeFile("examples/corner2.png")