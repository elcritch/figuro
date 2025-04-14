
import pixie

# proc superImage*(image: Image, x, y, w, h: int): Image

proc generateShadowImage(radius: int, offset: Vec2, 
                         spread: float32, blur: float32): Image =
  let adj = max(offset.x.abs().int, offset.y.abs().int) + 1*spread.int
  let sz = 2*radius + 2*adj

  let circle = newImage(sz, sz)
  let ctx3 = newContext(circle)
  ctx3.fillStyle = rgba(255, 255, 255, 255)
  ctx3.circle(radius.float32 + adj.float32, radius.float32 + adj.float32, radius.float32)
  ctx3.fill()

  let shadow3 = circle.shadow(
    offset = offset,
    spread = spread,
    blur = blur,
    color = rgba(0, 0, 0, 200)
  )

  let image3 = newImage(sz, sz)
  image3.fill(rgba(255, 255, 255, 255))
  image3.draw(shadow3)
  image3.draw(circle)
  return image3

# Example usage:
let shadowImage = generateShadowImage(
  radius = 50,
  offset = vec2(5, 10),
  spread = 10.0,
  blur = 10.0
)
shadowImage.writeFile("examples/corner2.png")