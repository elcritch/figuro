import pixie, pixie/simd


type
  Directions* = enum
    dTop
    dRight
    dBottom
    dLeft

  DirectionCorners* = enum
    dcTopLeft
    dcTopRight
    dcBottomRight
    dcBottomLeft

proc generateCircleBox*(
    radius: array[DirectionCorners, int],
    offset = vec2(0, 0),
    spread: float32 = 0.0'f32,
    blur: float32 = 0.0'f32,
    stroked: bool = true,
    lineWidth: float32 = 0.0'f32,
    fillStyle: ColorRGBA = rgba(255, 255, 255, 255),
    shadowColor: ColorRGBA = rgba(255, 255, 255, 255),
    outerShadow = true,
    innerShadow = true,
    innerShadowBorder = true,
): Image =
  var maxRadius = 0
  for r in radius:
    maxRadius = max(maxRadius, r)
  
  # Additional size for spread and blur
  let padding = (spread.int + blur.int)
  let totalSize = maxRadius * 2 + padding * 2
  
  # Create a canvas large enough to contain the box with all effects
  let img = newImage(totalSize, totalSize)
  let ctx = newContext(img)
  
  # Calculate the inner box dimensions
  let innerWidth = (totalSize - padding * 2).float32
  let innerHeight = (totalSize - padding * 2).float32
  
  # Create a path for the rounded rectangle with the given dimensions and corner radii
  proc createRoundedRectPath(
    innerWidth, innerHeight: float32,
    radius: array[DirectionCorners, int],
    padding: int
  ): Path =
    # Start at top right after the corner radius
    result = newPath()
    let topRight = vec2(innerWidth - radius[dcTopRight].float32, 0)
    result.moveTo(topRight + vec2(padding.float32, padding.float32))
    
    # Top right corner
    let trControl = vec2(innerWidth, 0)
    result.quadraticCurveTo(
      trControl + vec2(padding.float32, padding.float32),
      vec2(innerWidth, radius[dcTopRight].float32) + vec2(padding.float32, padding.float32)
    )
    
    # Right side
    result.lineTo(vec2(innerWidth, innerHeight - radius[dcBottomRight].float32) + vec2(padding.float32, padding.float32))
    
    # Bottom right corner
    let brControl = vec2(innerWidth, innerHeight)
    result.quadraticCurveTo(
      brControl + vec2(padding.float32, padding.float32),
      vec2(innerWidth - radius[dcBottomRight].float32, innerHeight) + vec2(padding.float32, padding.float32)
    )
    
    # Bottom side
    result.lineTo(vec2(radius[dcBottomLeft].float32, innerHeight) + vec2(padding.float32, padding.float32))
    
    # Bottom left corner
    let blControl = vec2(0, innerHeight)
    result.quadraticCurveTo(
      blControl + vec2(padding.float32, padding.float32),
      vec2(0, innerHeight - radius[dcBottomLeft].float32) + vec2(padding.float32, padding.float32)
    )
    
    # Left side
    result.lineTo(vec2(0, radius[dcTopLeft].float32) + vec2(padding.float32, padding.float32))
    
    # Top left corner
    let tlControl = vec2(0, 0)
    result.quadraticCurveTo(
      tlControl + vec2(padding.float32, padding.float32),
      vec2(radius[dcTopLeft].float32, 0) + vec2(padding.float32, padding.float32)
    )
    
    # Close the path
    result.lineTo(topRight + vec2(padding.float32, padding.float32))
  
  # Create the path for our rounded rectangle
  let path = createRoundedRectPath(innerWidth, innerHeight, radius, padding)
      
  # Draw the box
  if stroked:
    ctx.strokeStyle = fillStyle
    ctx.lineWidth = lineWidth
    ctx.stroke(path)
  else:
    ctx.fillStyle = fillStyle
    ctx.fill(path)
  
  # Apply inner shadow if requested
  if innerShadow or outerShadow:
    let shadow = img.shadow(
      offset = offset,
      spread = spread,
      blur = blur,
      color = shadowColor
    )

    let spath = createRoundedRectPath(innerWidth, innerHeight, radius, padding)

    let combined = newImage(totalSize, totalSize)
    let ctx = newContext(combined)
    if innerShadow:
      ctx.saveLayer()
      ctx.clip(spath, EvenOdd)
      ctx.drawImage(shadow, pos = vec2(0, 0))
      ctx.restore()
    if outerShadow:
      spath.rect(0, 0, totalSize.float32, totalSize.float32)
      ctx.saveLayer()
      ctx.clip(spath, EvenOdd)
      ctx.drawImage(shadow, pos = vec2(0, 0))
      ctx.restore()
    if innerShadowBorder:
      ctx.drawImage(img, pos = vec2(0, 0))
    return combined
  else:
    return img



let imgA = generateCircleBox(
  radius = [30, 20, 40, 10], # Different radius for each corner
  offset = vec2(0, 0),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = true,
  lineWidth = 2.0,
  outerShadow = false,
  innerShadow = false,
)

imgA.writeFile("examples/circlebox-asymmetric.png")

let imgAnostroke = generateCircleBox(
  radius = [30, 20, 40, 10], # Different radius for each corner
  offset = vec2(0, 0),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = false,
  lineWidth = 0.0,
  outerShadow = false,
  innerShadow = false,
)

imgAnostroke.writeFile("examples/circlebox-asymmetric-nostroke.png")


let imgB = generateCircleBox(
  radius = [30, 30, 30, 30], # Different radius for each corner
  offset = vec2(0, 0),
  spread = 0.0'f32,
  blur = 10.0'f32,
  stroked = false,
  lineWidth = 2.0,
  outerShadow = true,
  innerShadow = false,
)

imgB.writeFile("examples/circlebox-symmetric.png")

# Only inner shadow example
let imgC = generateCircleBox(
  radius = [30, 30, 30, 30],
  offset = vec2(0, 0),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = true,
  lineWidth = 2.0,
  outerShadow = false,
  innerShadow = true,
  innerShadowBorder = false,
)

imgC.writeFile("examples/circlebox-inner-only.png")

# Only outer shadow example
let imgD = generateCircleBox(
  radius = [30, 30, 30, 30],
  offset = vec2(2, 2),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = true,
  lineWidth = 2.0,
  outerShadow = true,
  innerShadow = false,
  innerShadowBorder = false,
)

imgD.writeFile("examples/circlebox-outer-only.png")

# Only outer shadow example
let imgE = generateCircleBox(
  radius = [30, 30, 30, 30],
  offset = vec2(0, 0),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = true,
  lineWidth = 2.0,
  outerShadow = true,
  innerShadow = true,
  innerShadowBorder = false,
)

imgE.writeFile("examples/circlebox-outer-inner.png")
