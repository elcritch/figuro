import pkg/pixie
import pkg/chroma

import ../../common/nodes/basics

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
  
  echo "sliceToNinePatch: ", width, "x", height, " halfW: ", halfW, " halfH: ", halfH

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
    
    top = img.subImage(centerX, 0, 1, centerY)
    right = img.subImage(centerX, centerY, width - centerX, 1)
    bottom = img.subImage(centerX, centerY, 1, height - centerY)
    left = img.subImage(0, centerY, centerX, 1)
  
  var
    n = 8
    ftop = newImage(n, top.height)
    fbottom = newImage(n, bottom.height)
    fright = newImage(right.width, n)
    fleft = newImage(left.width, n)

  for i in 0..<n:
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
  
proc getCircleBoxSizes*(
    radii: array[DirectionCorners, float32],
    blur: float32,
    spread: float32,
    weight: float32 = 0.0,
): tuple[maxRadius: int, totalSize: int, padding: int, inner: int] =
  result.maxRadius = 0
  for r in radii:
    result.maxRadius = max(result.maxRadius, r.ceil().int)
  result.padding = spread.ceil().int + blur.ceil().int
  result.totalSize = max(max(2*result.maxRadius + 2*result.padding, 4*result.padding), ceil(2*weight).int)
  result.inner = result.totalSize - 2*result.padding

proc generateCircleBox*(
    radii: array[DirectionCorners, float32],
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
    outerShadowFill = false,
): Image =
  
  # Additional size for spread and blur
  let lw = lineWidth.ceil()
  let (maxRadius, totalSize, padding, inner) = getCircleBoxSizes(radii, blur, spread)
  
  # Create a canvas large enough to contain the box with all effects
  let img = newImage(totalSize, totalSize)
  let bxy = newContext(img)
  
  # Calculate the inner box dimensions
  let innerWidth = inner.float32
  let innerHeight = inner.float32
  
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
    bxy.strokeStyle = fillStyle
    bxy.lineWidth = lineWidth
    bxy.stroke(path)
  else:
    bxy.fillStyle = fillStyle
    bxy.fill(path)
  
  # Apply inner shadow if requested
  if innerShadow or outerShadow or outerShadowFill:
    let spath = createRoundedRectPath(innerWidth, innerHeight, radii, padding.float32, lw)

    let ctxImg = newContext(img)
    if outerShadowFill:
      let spath = spath.copy()
      spath.rect(0, 0, totalSize.float32, totalSize.float32)
      ctxImg.saveLayer()
      ctxImg.clip(spath, EvenOdd)
      ctxImg.fillStyle = fillStyle
      ctxImg.rect(0, 0, totalSize.float32, totalSize.float32)
      ctxImg.fill()
      ctxImg.restore()

    let shadow = img.shadow(
      offset = offset,
      spread = spread,
      blur = blur,
      color = shadowColor
    )

    let combined = newImage(totalSize, totalSize)
    let bxy = newContext(combined)
    if innerShadow:
      bxy.saveLayer()
      bxy.clip(spath, EvenOdd)
      bxy.drawImage(shadow, pos = vec2(0, 0))
      bxy.drawImage(shadow, pos = vec2(0, 0))
      bxy.drawImage(shadow, pos = vec2(0, 0))
      bxy.restore()
    if outerShadow:
      let spath = spath.copy()
      spath.rect(0, 0, totalSize.float32, totalSize.float32)
      bxy.saveLayer()
      bxy.clip(spath, EvenOdd)
      bxy.drawImage(shadow, pos = vec2(0, 0))
      bxy.restore()
    if innerShadowBorder:
      bxy.drawImage(img, pos = vec2(0, 0))
    return combined
  else:
    return img
