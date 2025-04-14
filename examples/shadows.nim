import pixie

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

proc sliceToNinePatch*(img: Image, cornerSize: int): tuple[
  topLeft, topRight, bottomLeft, bottomRight: Image,
  top, right, bottom, left: Image
] =
  ## Slices an image into 8 pieces for a 9-patch style UI renderer.
  ## The ninth piece (center) is not included as it's typically transparent or filled separately.
  ## Returns the four corners and four edges as separate images.
  
  let 
    width = img.width
    height = img.height
    halfW = width div 2
    halfH = height div 2
  
  # Create the corner images - using the actual corner size or half the image size, whichever is smaller
  let 
    actualCornerW = min(cornerSize, halfW)
    actualCornerH = min(cornerSize, halfH)
  
  # Four corners
  let
    topLeft = superImage(img, 0, 0, actualCornerW, actualCornerH)
    topRight = superImage(img, width - actualCornerW, 0, actualCornerW, actualCornerH)
    bottomLeft = superImage(img, 0, height - actualCornerH, actualCornerW, actualCornerH)
    bottomRight = superImage(img, width - actualCornerW, height - actualCornerH, actualCornerW, actualCornerH)
  
  # Four edges (1 pixel wide for sides, full width/height for top/bottom)
  let
    top = superImage(img, actualCornerW, 0, width - 2*actualCornerW, 1)
    right = superImage(img, width - 1, actualCornerH, 1, height - 2*actualCornerH)
    bottom = superImage(img, actualCornerW, height - 1, width - 2*actualCornerW, 1)
    left = superImage(img, 0, actualCornerH, 1, height - 2*actualCornerH)
  
  result = (
    topLeft: topLeft,
    topRight: topRight,
    bottomLeft: bottomLeft,
    bottomRight: bottomRight,
    top: top,
    right: right,
    bottom: bottom,
    left: left
  )

# Example usage:
let shadowImage = generateShadowImage(
  radius = 50,
  offset = vec2(5, 10),
  spread = 10.0,
  blur = 10.0
)
shadowImage.writeFile("examples/corner2.png")

# Example of slicing the shadow image into a 9-patch
let ninePatch = sliceToNinePatch(shadowImage, 30)
ninePatch.topLeft.writeFile("examples/shadow_top_left.png")
ninePatch.topRight.writeFile("examples/shadow_top_right.png")
ninePatch.bottomLeft.writeFile("examples/shadow_bottom_left.png")
ninePatch.bottomRight.writeFile("examples/shadow_bottom_right.png")
ninePatch.top.writeFile("examples/shadow_top.png")
ninePatch.right.writeFile("examples/shadow_right.png")
ninePatch.bottom.writeFile("examples/shadow_bottom.png")
ninePatch.left.writeFile("examples/shadow_left.png")