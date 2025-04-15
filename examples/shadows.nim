import pixie, pixie/simd

proc generateShadowImage(
    radius: int, offset: Vec2, 
    spread: float32, blur: float32,
    fillStyle: ColorRGBA = rgba(255, 255, 255, 255),
    shadowColor: ColorRGBA = rgba(255, 255, 255, 255)
): Image =
  let adj = abs(spread.int+blur.int)
  let sz = 2*radius + 2*adj

  let circle = newImage(sz, sz)
  let ctx3 = newContext(circle)
  let center = radius.float32 + adj.float32
  ctx3.fillStyle = fillStyle
  ctx3.circle(center, center, radius.float32)
  ctx3.fill()

  let shadow3 = circle.shadow(
    offset = offset,
    spread = spread,
    blur = blur,
    color = shadowColor
  )

  let image = newImage(sz, sz)
  image.draw(shadow3)
  # echo "shadowImage: ", image.width, " ", image.height
  return image

# Example usage:
let shadowImage = generateShadowImage(
  radius = 100,
  offset = vec2(0, 0),
  spread = 0.0,
  blur = 100.0,
  fillStyle = rgba(255, 255, 255, 255),
  shadowColor = rgba(255, 255, 255, 255),
)
# shadowImage.invert()
shadowImage.writeFile("examples/shadow.png")
