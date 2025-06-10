# import glcommons
import std/hashes

import ../../commons
import ../../common/nodes/render

import pkg/chroma
import pkg/sigils
import pkg/chronicles
import pkg/pixie/images
import pkg/sdfy

import ../utils/boxes
import ./drawutils

var shadowCache: Table[Hash, Image] = initTable[Hash, Image]()

proc fillRoundedRectWithShadow*[R](
    ctx: R,
    rect: Rect,
    radii: array[DirectionCorners, float32],
    shadowX, shadowY, shadowBlur, shadowSpread: float32,
    shadowColor: Color,
    innerShadow = false,
) =
  ## Draws a rounded rectangle with a shadow underneath using 9-patch technique
  ## The shadow is drawn with padding around the main rectangle
  if rect.w <= 0 or rect.h <= 0:
    return
    
  # First, draw the shadow
  # Generate shadow key for caching
  proc getShadowKey(blur: float32, spread: float32, radius: float32, innerShadow: bool): Hash =
    hash((7723, (blur * 1).int, (spread * 1).int, (radius * 1).int, innerShadow))

  let 
    radii = clampRadii(radii, rect)
    radiusLimit = max(radii)
    # maxRadius = radiusLimit
    shadowBlurSize = shadowBlur
    shadowSpread = shadowSpread
    shadowKey = getShadowKey(shadowBlurSize, shadowSpread, radiusLimit, innerShadow)
  
  let (maxRadius, sideSize, totalSize, padding, inner) = getCircleBoxSizes(radii, shadowBlur, shadowSpread, 0.0, rect.w, rect.h)
  
  var ninePatchHashes: array[8, Hash]
  for i in 0..7:
    ninePatchHashes[i] = shadowKey !& i

  # Check if we've already generated this shadow
  let shadowKeyBase = shadowKey !& 0
  # let newSize = max(shadowBlur.int + shadowSpread.int + maxRadius.int, 2)
  let newSize = totalSize

  if shadowKeyBase notin ctx.entries:
    var shadowImg: Image =
      if innerShadow:
        let mainKey = getShadowKey(shadowBlurSize, shadowSpread, radiusLimit, innerShadow)
        # Generate shadow image
        if mainKey notin shadowCache:
          echo "generating main shadow image: ", mainKey, " blur: ", shadowBlurSize.round(2), " spread: ", shadowSpread.round(2), " radius: ", radiusLimit.round(2), " ", innerShadow
          let mainImg = generateCircleBox(
            radii = radii,
            offset = vec2(0, 0),
            spread = shadowSpread,
            blur = shadowBlur,
            stroked = true,
            lineWidth = 1.0,
            innerShadow = true,
            outerShadow = false,
            innerShadowBorder = true,
            outerShadowFill = true,
          )
          # mainImg.writeFile("examples/renderer-shadowImage-" & $innerShadow & ".png")
          shadowCache[mainKey] = mainImg
          mainImg
        else:
          shadowCache[mainKey]
      else:
        let mainKey = getShadowKey(shadowBlurSize, shadowSpread, radiusLimit, innerShadow)
        if mainKey notin shadowCache:
          let mainImg = generateCircleBox(
            radii = radii,
            offset = vec2(0, 0),
            spread = shadowSpread,
            blur = shadowBlurSize,
            stroked = false,
            lineWidth = 1.0,
            outerShadow = true,
            innerShadow = false,
            innerShadowBorder = true,
            outerShadowFill = false,
          )
          # mainImg.writeFile("examples/renderer-shadowImage-" & $innerShadow & ".png")
          shadowCache[mainKey] = mainImg
          mainImg
        else:
          shadowCache[mainKey]

    if shadowImg.width != newSize or shadowImg.height != newSize:
      shadowImg = shadowImg.resize(newSize, newSize)

    # Slice it into 9-patch pieces
    let patches = sliceToNinePatch(shadowImg)

    # Store each piece in the atlas
    let patchArray = [
      patches.topLeft, patches.topRight, 
      patches.bottomLeft, patches.bottomRight,
      patches.top, patches.right, 
      patches.bottom, patches.left
    ]

    for i in 0..7:
      ninePatchHashes[i] = shadowKey !& i
      ctx.putImage(ninePatchHashes[i], patchArray[i])

  var 
    # totalPadding = int(shadowBlur+shadowSpread) - 1
    totalPadding = padding.int
    corner = totalPadding.float32 + inner.float32/2 + 1

  let
    sbox = rect(
      rect.x - totalPadding.float32 + shadowX,
      rect.y - totalPadding.float32 + shadowY,
      rect.w + 2 * totalPadding.float32,
      rect.h + 2 * totalPadding.float32
    )
    halfW = sbox.w / 2
    halfH = sbox.h / 2
    centerX = sbox.x + halfW
    centerY = sbox.y + halfH

  # Draw the corners
  let 
    topLeft = rect(sbox.x, sbox.y, corner, corner)
    topRight = rect(sbox.x + sbox.w - corner, sbox.y, corner, corner)
    bottomLeft = rect(sbox.x, sbox.y + sbox.h - corner, corner, corner)
    bottomRight = rect(sbox.x + sbox.w - corner, sbox.y + sbox.h - corner, corner, corner)
  
  # Draw corners
  ctx.drawImageAdj(ninePatchHashes[0], topLeft.xy, shadowColor, topLeft.wh)
  ctx.drawImageAdj(ninePatchHashes[1], topRight.xy, shadowColor, topRight.wh)
  ctx.drawImageAdj(ninePatchHashes[2], bottomLeft.xy, shadowColor, bottomLeft.wh)
  ctx.drawImageAdj(ninePatchHashes[3], bottomRight.xy, shadowColor, bottomRight.wh)
  
  # Draw edges
  # Top edge (stretched horizontally)
  let topEdge = rect(sbox.x + corner, sbox.y, sbox.w - 2 * corner, corner)
  ctx.drawImageAdj(ninePatchHashes[4], topEdge.xy, shadowColor, topEdge.wh)
  let rightEdge = rect( sbox.x + sbox.w - corner, sbox.y + corner, corner, sbox.h - 2 * corner)
  ctx.drawImageAdj(ninePatchHashes[5], rightEdge.xy, shadowColor*1.0, rightEdge.wh)
  let bottomEdge = rect( sbox.x + corner, sbox.y + sbox.h - corner, sbox.w - 2 * corner, corner)
  ctx.drawImageAdj(ninePatchHashes[6], bottomEdge.xy, shadowColor*1.0, bottomEdge.wh)
  let leftEdge = rect( sbox.x, sbox.y + corner, corner, sbox.h - 2 * corner)
  ctx.drawImageAdj(ninePatchHashes[7], leftEdge.xy, shadowColor*1.0, leftEdge.wh)
  
  # Center (stretched both ways)
  let center = rect(sbox.x + corner, sbox.y + corner, sbox.w - 2 * corner, sbox.h - 2 * corner)
  if not innerShadow:
    ctx.drawRect(center, shadowColor)

proc fillRoundedRectWithShadowSdf*[R](
    ctx: R,
    rect: Rect,
    radii: array[DirectionCorners, float32],
    shadowX, shadowY, shadowBlur, shadowSpread: float32,
    shadowColor: Color,
    innerShadow = false,
) =
  ## Draws a rounded rectangle with a shadow underneath using 9-patch technique
  ## The shadow is drawn with padding around the main rectangle
  if rect.w <= 0 or rect.h <= 0:
    return
    
  # First, draw the shadow
  # Generate shadow key for caching
  proc getShadowKey(blur: float32, spread: float32, radius: float32, innerShadow: bool): Hash =
    hash((7723, (blur * 1).int, (spread * 1).int, (radius * 1).int, innerShadow))

  let 
    radii = clampRadii(radii, rect)
    # maxRadius = radiusLimit
    cbs  = getCircleBoxSizes(radii, 0.0, 0.0, 0.0, rect.w, rect.h)
    radiusLimit = cbs.maxRadius
    # shadowBlurSizeLimit = shadowBlur
    # shadowSpreadLimit = shadowSpread
    shadowBlurSize = shadowBlur
    shadowSpread = shadowSpread
    shadowKey = getShadowKey(shadowBlurSize, shadowSpread, radiusLimit, innerShadow)
  
  let (maxRadius, sideSize, totalSize, padding, inner) = getCircleBoxSizes(radii, shadowBlur, shadowSpread, 0.0, rect.w, rect.h)
  
  var ninePatchHashes: array[8, Hash]
  for i in 0..7:
    ninePatchHashes[i] = shadowKey !& i

  # Check if we've already generated this shadow
  let shadowKeyBase = shadowKey !& 0
  # let newSize = max(shadowBlur.int + shadowSpread.int + maxRadius.int, 2)
  let newSize = totalSize

  if shadowKeyBase notin ctx.entries:
    const whiteColor = rgba(255, 255, 255, 255)
    var center = vec2(rect.x + cbs.sideSize.float32, rect.y + cbs.sideSize.float32)
    let wh = vec2(2*cbs.sideSize.float32, 2*cbs.sideSize.float32)
    let corners = vec4(radii[dcBottomLeft], radii[dcTopRight], radii[dcBottomRight], radii[dcTopLeft])
    let shadowImg = newImage(newSize, newSize)

    if innerShadow:
      let mainKey = getShadowKey(shadowBlurSize, shadowSpread, radiusLimit, innerShadow)
      # Generate shadow image
      if mainKey notin shadowCache:
        # echo "generating main shadow image: ", mainKey, " blur: ", shadowBlurSizeLimit.round(2), " spread: ", shadowSpreadLimit.round(2), " radius: ", radiusLimit.round(2), " ", innerShadow
        discard
      else:
        shadowImg = shadowCache[mainKey]
    else:
      let mainKey = getShadowKey(shadowBlurSize, shadowSpread, radiusLimit, innerShadow)
      # echo "generating main shadow image: ", mainKey, " blur: ", shadowBlurSizeLimit.round(2), " spread: ", shadowSpreadLimit.round(2), " radius: ", radiusLimit.round(2), " ", innerShadow
      if mainKey notin shadowCache:
          drawSdfShape(
                  shadowImg,
                  center = center,
                  wh = wh,
                  params = RoundedBoxParams(r: corners),
                  pos = whiteColor,
                  neg = whiteColor,
                  factor = shadowBlur, 
                  spread = shadowSpread,
                  mode = sdfModeDropShadow)
          shadowCache[mainKey] = shadowImg
          shadowImg
      else:
        shadowImg = shadowCache[mainKey]

    # Slice it into 9-patch pieces
    let patches = sliceToNinePatch(shadowImg)

    # Store each piece in the atlas
    let patchArray = [
      patches.topLeft, patches.topRight, 
      patches.bottomLeft, patches.bottomRight,
      patches.top, patches.right, 
      patches.bottom, patches.left
    ]

    for i in 0..7:
      ninePatchHashes[i] = shadowKey !& i
      ctx.putImage(ninePatchHashes[i], patchArray[i])

  var 
    # totalPadding = int(shadowBlur+shadowSpread) - 1
    totalPadding = padding.int
    corner = totalPadding.float32 + inner.float32/2 + 1

  let
    sbox = rect(
      rect.x - totalPadding.float32 + shadowX,
      rect.y - totalPadding.float32 + shadowY,
      rect.w + 2 * totalPadding.float32,
      rect.h + 2 * totalPadding.float32
    )
    halfW = sbox.w / 2
    halfH = sbox.h / 2
    centerX = sbox.x + halfW
    centerY = sbox.y + halfH

  # Draw the corners
  let 
    topLeft = rect(sbox.x, sbox.y, corner, corner)
    topRight = rect(sbox.x + sbox.w - corner, sbox.y, corner, corner)
    bottomLeft = rect(sbox.x, sbox.y + sbox.h - corner, corner, corner)
    bottomRight = rect(sbox.x + sbox.w - corner, sbox.y + sbox.h - corner, corner, corner)
  
  # Draw corners
  ctx.drawImageAdj(ninePatchHashes[0], topLeft.xy, shadowColor, topLeft.wh)
  ctx.drawImageAdj(ninePatchHashes[1], topRight.xy, shadowColor, topRight.wh)
  ctx.drawImageAdj(ninePatchHashes[2], bottomLeft.xy, shadowColor, bottomLeft.wh)
  ctx.drawImageAdj(ninePatchHashes[3], bottomRight.xy, shadowColor, bottomRight.wh)
  
  # Draw edges
  # Top edge (stretched horizontally)
  let topEdge = rect(sbox.x + corner, sbox.y, sbox.w - 2 * corner, corner)
  ctx.drawImageAdj(ninePatchHashes[4], topEdge.xy, shadowColor, topEdge.wh)
  let rightEdge = rect( sbox.x + sbox.w - corner, sbox.y + corner, corner, sbox.h - 2 * corner)
  ctx.drawImageAdj(ninePatchHashes[5], rightEdge.xy, shadowColor*1.0, rightEdge.wh)
  let bottomEdge = rect( sbox.x + corner, sbox.y + sbox.h - corner, sbox.w - 2 * corner, corner)
  ctx.drawImageAdj(ninePatchHashes[6], bottomEdge.xy, shadowColor*1.0, bottomEdge.wh)
  let leftEdge = rect( sbox.x, sbox.y + corner, corner, sbox.h - 2 * corner)
  ctx.drawImageAdj(ninePatchHashes[7], leftEdge.xy, shadowColor*1.0, leftEdge.wh)
  
  # Center (stretched both ways)
  let center = rect(sbox.x + corner, sbox.y + corner, sbox.w - 2 * corner, sbox.h - 2 * corner)
  if not innerShadow:
    ctx.drawRect(center, shadowColor)