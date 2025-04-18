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
proc drawCircle(ctx: Context, center, radius: float, lineWidth: float, stroke: bool, color: ColorRGBA) =
  ctx.strokeStyle = color
  ctx.fillStyle = color
  ctx.lineCap = SquareCap
  ctx.lineWidth = lineWidth
  ctx.circle(center, center, radius)
  if stroke:
    ctx.stroke()
  else:
    ctx.fill()

proc gaussianFunction*(x: float, mean: float = 0.0, stdDev: float = 1.0): float =
  ## Creates a Gaussian (normal) distribution function
  ## 
  ## Parameters:
  ##   mean: The mean (μ) of the distribution
  ##   stdDev: The standard deviation (σ) of the distribution
  ## 
  ## Returns:
  ##   A function that takes an x value and returns the probability density
  
  # Constant factors for the Gaussian formula
  let factor = 1.0 / (stdDev * sqrt(2.0 * PI))
  let exponentFactor = -1.0 / (2.0 * stdDev * stdDev)
  
  # Return a closure that calculates the Gaussian probability density
  # Calculate (x - mean)²
  let deviation = x - mean
  let deviationSquared = deviation * deviation
  
  # Calculate e^(-((x-mean)²)/(2σ²))
  let exponent = deviationSquared * exponentFactor
  
  # Return the complete formula: (1/(σ√(2π))) * e^(-((x-mean)²)/(2σ²))
  result = factor * exp(exponent)

proc generateCircle(radius: int, offset: Vec2, 
                         spread: float32, blur: float32,
                         lineWidth: float32 = 0'f32,
                         stroked: bool = true,
                         fillStyle: ColorRGBA = rgba(255, 255, 255, 255),
                         shadowColor: ColorRGBA = rgba(0, 0, 0, 255),
                         innerShadow = false,
                         innerShadowBorder = false,
                         ): Image =
  let sz = 2*radius
  let radius = radius.toFloat
  let center = radius.float32

  let circle = newImage(sz, sz)
  let ctxCircle = newContext(circle)
  drawCircle(ctxCircle, radius, radius - lineWidth/2, lineWidth, true, fillStyle)

  var image = newImage(sz, sz)

  # if innerShadow:
  #   let shadow = circle.shadow(
  #     offset = offset,
  #     spread = spread,
  #     blur = blur,
  #     color = shadowColor)
  #   image.draw(shadow)

  image.draw(circle)

  if innerShadow:
    let circleInner = newImage(sz, sz)
    circleInner.fill(rgba(255, 255, 255, 255))

    let circleSolid = newImage(sz, sz)
    let ctx = newContext(circleSolid)
    ctx.fillStyle = rgba(255, 255, 255, 255)
    ctx.circle(radius, radius, radius-2*lineWidth)
    ctx.fill()

    circleInner.draw(circleSolid, blendMode = SubtractMaskBlend)

    let innerRadius = radius/2
    let cnt = radius*2
    for i in 0..cnt.int:
      block:
        let i = i.float32
        let cl = newImage(sz, sz)
        let ctxCl = newContext(cl)
        # let fs = rgba(255, 255, 255, uint8(170*(1-sin(i/cnt*PI/2))))
        let fs = rgba(255, 255, 255, uint8((255*gaussianFunction(i/cnt*PI/2, mean = -0.3, stdDev = 0.49))))
        let radius = radius-2*lineWidth - i/cnt*(radius-innerRadius)
        # let lw = 1.float32 * (1-i/cnt)
        let lw = 1.float32
        # echo "circleInner: ", i, " fs: ", fs, " radius: ", radius
        drawCircle(ctxCl, center = center, radius = radius, lineWidth = lw, stroke = true, color = fs)
        image.draw(cl)
    image.draw(circle)
    image.draw(circleInner)
  return image

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
when true:
  let circleImage = generateCircle(
    radius = 100,
    stroked = true,
    offset = vec2(0, 0),
    spread = 20.0,
    blur = 40.0,
    lineWidth = 10.0,
    fillStyle = rgba(255, 255, 255, 255),
    shadowColor = rgba(255, 255, 255, 255),
    innerShadow = false,
    innerShadowBorder = false,
  )
  circleImage.writeFile("examples/circle.png")

# Example usage:
let shadowImage = generateCircle(
  radius = 100,
  stroked = true,
  offset = vec2(0, 0),
  spread = 20.0,
  blur = 40.0,
  lineWidth = 10.0,
  fillStyle = rgba(255, 255, 255, 255),
  shadowColor = rgba(255, 255, 255, 255),
  innerShadow = true,
  innerShadowBorder = true,
)
shadowImage.writeFile("examples/innerShadow.png")

# Example of slicing the shadow image into a 9-patch
let ninePatch = sliceToNinePatch(shadowImage)
# ninePatch.topLeft.writeFile("examples/shadow_top_left.png")
# ninePatch.topRight.writeFile("examples/shadow_top_right.png")
# ninePatch.bottomLeft.writeFile("examples/shadow_bottom_left.png")
# ninePatch.bottomRight.writeFile("examples/shadow_bottom_right.png")
# ninePatch.top.writeFile("examples/shadow_top.png")
# ninePatch.right.writeFile("examples/shadow_right.png")
# ninePatch.bottom.writeFile("examples/shadow_bottom.png")
# ninePatch.left.writeFile("examples/shadow_left.png")