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

proc sliceToNinePatch*(img: Image): tuple[
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
    actualCornerW = halfW
    actualCornerH = halfH
  
  # Four corners
  let
    topLeft = img.subImage(0, 0, halfW, halfH)
    topRight = img.subImage(width - halfW, 0, halfW, halfH)
    bottomLeft = img.subImage(0, height - halfH, halfW, halfH)
    bottomRight = img.subImage(width - halfW, height - halfH, halfW, halfH)
  
  # Four edges (1 pixel wide for sides, full width/height for top/bottom)
  # Each edge goes from the center point to the edge
  let
    centerX = width div 2
    centerY = height div 2
    
    # Top edge: from center to top edge, 1px wide
    top = img.subImage(centerX, 0, 1, centerY)
    
    # Right edge: from center to right edge, 1px high  
    right = img.subImage(centerX, centerY, width - centerX, 1)
    
    # Bottom edge: from center to bottom edge, 1px wide
    bottom = img.subImage(centerX, centerY, 1, height - centerY)
    
    # Left edge: from left edge to center, 1px high
    left = img.subImage(0, centerY, centerX, 1)
  
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
let ninePatch = sliceToNinePatch(shadowImage)
ninePatch.topLeft.writeFile("examples/shadow_top_left.png")
ninePatch.topRight.writeFile("examples/shadow_top_right.png")
ninePatch.bottomLeft.writeFile("examples/shadow_bottom_left.png")
ninePatch.bottomRight.writeFile("examples/shadow_bottom_right.png")
ninePatch.top.writeFile("examples/shadow_top.png")
ninePatch.right.writeFile("examples/shadow_right.png")
ninePatch.bottom.writeFile("examples/shadow_bottom.png")
ninePatch.left.writeFile("examples/shadow_left.png")