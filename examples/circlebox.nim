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
    radii: array[DirectionCorners, float32],
    offset = vec2(0, 0),
    spread: float32 = 0.0'f32,
    blur: float32 = 0.0'f32,
    stroked: bool = true,
    filled: bool = true,
    lineWidth: float32 = 0.0'f32,
    fillStyle: ColorRGBA = rgba(255, 255, 255, 255),
    shadowColor: ColorRGBA = rgba(255, 255, 255, 255),
    outerShadow = true,
    innerShadow = true,
    innerShadowBorder = true,
    outerShadowFill = false,
): Image =
  var maxRadius = 0.0
  for r in radii:
    maxRadius = max(maxRadius, r)
  
  # Additional size for spread and blur
  let padding = (spread.int + blur.int)
  let lw = lineWidth.ceil()
  let totalSize = max(maxRadius.ceil().int * 2 + padding * 2, 10+padding*2)
  
  # Create a canvas large enough to contain the box with all effects
  let img = newImage(totalSize, totalSize)
  let ctx = newContext(img)
  
  # Calculate the inner box dimensions
  let innerWidth = (totalSize - padding * 2).float32
  let innerHeight = (totalSize - padding * 2).float32

  # Create a path for the rounded rectangle with the given dimensions and corner radii
  proc createRoundedRectPath(
    width, height: float32,
    radii: array[DirectionCorners, float32],
    padding: float32,
    lw: float32
  ): pixie.Path =
    # Start at top right after the corner radius
    let hlw = lw / 2.0
    let padding = padding + hlw
    let width = width - lw
    let height = height - lw

    result = newPath()
    let topRight = vec2(width - radii[dcTopRight], 0)
    result.moveTo(topRight + vec2(padding, padding))
    
    # Top right corner
    let trControl = vec2(width, 0)
    result.quadraticCurveTo(
      trControl + vec2(padding, padding),
      vec2(width, radii[dcTopRight]) + vec2(padding, padding)
    )
    
    # Right side
    result.lineTo(vec2(width, height - radii[dcBottomRight]) + vec2(padding, padding))
    
    # Bottom right corner
    let brControl = vec2(width, height)
    result.quadraticCurveTo(
      brControl + vec2(padding, padding),
      vec2(width - radii[dcBottomRight], height) + vec2(padding, padding)
    )
    
    # Bottom side
    result.lineTo(vec2(radii[dcBottomLeft], height) + vec2(padding, padding))
    
    # Bottom left corner
    let blControl = vec2(0, height)
    result.quadraticCurveTo(
      blControl + vec2(padding, padding),
      vec2(0, height - radii[dcBottomLeft]) + vec2(padding, padding)
    )
    
    # Left side
    result.lineTo(vec2(0, radii[dcTopLeft]) + vec2(padding, padding))
    
    # Top left corner
    let tlControl = vec2(0, 0)
    result.quadraticCurveTo(
      tlControl + vec2(padding, padding),
      vec2(radii[dcTopLeft], 0) + vec2(padding, padding)
    )
    
    # Close the path
    result.lineTo(topRight + vec2(padding, padding))
  
  # Create the path for our rounded rectangle
  let path = createRoundedRectPath(innerWidth, innerHeight, radii, padding.float32, lw)
      
  # Draw the box
  if stroked:
    ctx.strokeStyle = fillStyle
    ctx.lineWidth = lineWidth
    ctx.stroke(path)

  if filled:
    ctx.fillStyle = fillStyle
    ctx.fill(path)
  
  # Apply inner shadow if requested
  if innerShadow or outerShadow or outerShadowFill:
    let shadow = img.shadow(
      offset = offset,
      spread = spread,
      blur = blur,
      color = shadowColor
    )

    let spath = createRoundedRectPath(innerWidth, innerHeight, radii, padding.float32, lw)

    let combined = newImage(totalSize, totalSize)
    let ctx = newContext(combined)
    if innerShadow:
      ctx.saveLayer()
      ctx.clip(spath, EvenOdd)
      ctx.drawImage(shadow, pos = vec2(0, 0))
      ctx.restore()
    if outerShadowFill:
      let spath = spath.copy()
      spath.rect(0, 0, totalSize.float32, totalSize.float32)
      ctx.saveLayer()
      ctx.clip(spath, EvenOdd)
      ctx.fillStyle = fillStyle
      ctx.rect(0, 0, totalSize.float32, totalSize.float32)
      ctx.fill()
      ctx.restore()
    if outerShadow:
      let spath = spath.copy()
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
  radii = [0'f32, 20'f32, 40'f32, 10'f32], # Different radius for each corner
  offset = vec2(0, 0),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = true,
  lineWidth = 2.0,
  outerShadow = false,
  innerShadow = false,
)

imgA.writeFile("examples/circlebox-asymmetric.png")

let imgAstroke = generateCircleBox(
  radii = [0'f32, 20'f32, 40'f32, 10'f32], # Different radius for each corner
  offset = vec2(0, 0),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = true,
  filled = true,
  lineWidth = 2.0,
  outerShadow = false,
  innerShadow = false,
)

imgAstroke.writeFile("examples/circlebox-asymmetric-stroke.png")

let imgAnostroke = generateCircleBox(
  radii = [30'f32, 20'f32, 40'f32, 10'f32], # Different radius for each corner
  offset = vec2(0, 0),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = false,
  lineWidth = 0.0,
  outerShadow = false,
  innerShadow = false,
)

imgAnostroke.writeFile("examples/circlebox-asymmetric-nostroke.png")

let imgAfillshadow = generateCircleBox(
  radii = [30'f32, 20'f32, 40'f32, 10'f32], # Different radius for each corner
  offset = vec2(0, 0),
  spread = 20.0'f32,
  blur = 20.0'f32,
  stroked = false,
  lineWidth = 0.0,
  outerShadow = true,
  innerShadow = false,
  innerShadowBorder = true,
  outerShadowFill = false,
)

imgAfillshadow.writeFile("examples/circlebox-asymmetric-fill-shadow.png")


let imgB = generateCircleBox(
  radii = [1'f32, 1'f32, 1'f32, 1'f32], # Different radius for each corner
  offset = vec2(0, 0),
  spread = 0.0'f32,
  blur = 10.0'f32,
  stroked = false,
  lineWidth = 2.0,
  outerShadow = true,
  innerShadow = false,
  innerShadowBorder = true,
)

imgB.writeFile("examples/circlebox-symmetric.png")

# Only inner shadow example
let imgC = generateCircleBox(
  radii = [30'f32, 30'f32, 30'f32, 30'f32],
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
  radii = [30'f32, 30'f32, 30'f32, 30'f32],
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
  radii = [30'f32, 30'f32, 30'f32, 30'f32],
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

let imgF = generateCircleBox(
  radii = [30'f32, 30'f32, 30'f32, 30'f32],
  offset = vec2(0, 0),
  spread = 1.0'f32,
  blur = 10.0'f32,
  stroked = true,
  lineWidth = 2.0,
  outerShadow = true,
  innerShadow = true,
  innerShadowBorder = false,
  outerShadowFill = true,
)

imgF.writeFile("examples/circlebox-inner-and-fill-outer.png")

let imgG = generateCircleBox(
  radii = [10'f32, 10'f32, 10'f32, 10'f32],
  offset = vec2(0, 0),
  spread = 0.0'f32,
  blur = 5.0'f32,
  stroked = true,
  lineWidth = 2.0,
  outerShadow = false,
  innerShadow = true,
  innerShadowBorder = true,
  outerShadowFill = true,
)

imgG.writeFile("examples/circlebox-inner-and-fill-outer-0radius.png")
