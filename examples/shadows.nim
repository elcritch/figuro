import pixie, pixie/simd

proc delta*(image: Image) {.hasSimd, raises: [].} =
  ## Inverts all of the colors and alpha.
  for i in 0 ..< image.data.len:
    var rgbx = image.data[i]
    let r = (rgbx.r != 0).uint8
    rgbx.a = (255-rgbx.g) * r
    rgbx.r = (255) * r
    rgbx.g = (255) * r
    rgbx.b = (255) * r
    image.data[i] = rgbx

  # Inverting rgbx(50, 100, 150, 200) becomes rgbx(205, 155, 105, 55). This
  # is not a valid premultiplied alpha color.
  # We need to convert back to premultiplied alpha after inverting.
  # image.data.toPremultipliedAlpha()

proc generateShadowImage(radius: int, offset: Vec2, 
                         spread: float32, blur: float32,
                         fillStyle: ColorRGBA = rgba(255, 255, 255, 255),
                         shadowColor: ColorRGBA = rgba(0, 0, 0, 255)
                         ): Image =
  let adj = 2*abs(spread.int)
  let sz = 2*radius + 2*adj

  let circle = newImage(sz, sz)
  let ctx3 = newContext(circle)
  ctx3.strokeStyle = fillStyle
  ctx3.lineCap = SquareCap
  ctx3.lineWidth = 5.0'f32
  ctx3.circle(radius.float32 + adj.float32, radius.float32 + adj.float32, radius.float32)
  ctx3.stroke()

  let circleSolid = newImage(sz, sz)
  let ctx4 = newContext(circleSolid)
  ctx4.fillStyle = fillStyle
  ctx4.circle(radius.float32 + adj.float32, radius.float32 + adj.float32, radius.float32)
  ctx4.fill()
  
  let shadow3 = circle.shadow(
    offset = offset,
    spread = spread,
    blur = blur,
    color = shadowColor
  )

  let image3 = newImage(sz, sz)
  image3.draw(shadow3)
  image3.draw(circle)
  image3.draw(circleSolid, blendMode = MaskBlend)
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
  
  var
    ftop = newImage(4, top.height)
    fbottom = newImage(4, bottom.height)
    fright = newImage(right.width, 4)
    fleft = newImage(left.width, 4)

  for i in 0..3:
    ftop.draw(top, translate(vec2(i.float32, 0)))
    fbottom.draw(bottom, translate(vec2(i.float32, 0)))
    fright.draw(right, translate(vec2(0, i.float32)))
    fleft.draw(left, translate(vec2(0, i.float32)))

  result = (
    topLeft: topLeft,
    topRight: topRight,
    bottomLeft: bottomLeft,
    bottomRight: bottomRight,
    top: ftop,
    right: fright,
    bottom: fbottom,
    left: fleft
  )

# Example usage:
let shadowImage = generateShadowImage(
  radius = 40,
  offset = vec2(0, 0),
  spread = 5.0,
  blur = 10.0,
  fillStyle = rgba(255, 255, 255, 255),
  shadowColor = rgba(255, 255, 255, 100),
)
# shadowImage.invert()
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