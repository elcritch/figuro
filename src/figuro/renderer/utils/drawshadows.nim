# import glcommons
import std/hashes

import ../../commons
import ../../common/nodes/render

import pkg/chroma
import pkg/sigils
import pkg/chronicles
import pkg/pixie
import pkg/sdfy

import ../utils/boxes
import ./drawutils

var shadowCache: Table[Hash, Image] = initTable[Hash, Image]()

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
  proc getShadowKey(blur: float32, spread: float32, innerShadow: bool, radii: array[DirectionCorners, float32]): Hash =
    result = hash((7723, blur.int, spread.int, innerShadow))
    result = result !& radii[dcTopLeft].int !& radii[dcTopRight].int !& radii[dcBottomLeft].int !& radii[dcBottomRight].int

  let 
    radii = clampRadii(radii, rect)
    shadowBlur = shadowBlur.round().float32
    shadowSpread = shadowSpread.round().float32
    cbs  = getCircleBoxSizes(radii, blur = shadowBlur,
                             spread = shadowSpread,
                             weight = 0.0,
                             width = rect.w,
                             height = rect.h,
                             innerShadow = innerShadow)
    maxRadius = cbs.maxRadius
    shadowKey = getShadowKey(shadowBlur, shadowSpread, innerShadow, radii)
    wh = vec2(cbs.inner.float32, cbs.inner.float32)
  
  var ninePatchHashes: array[8, Hash]
  for i in 0..7:
    ninePatchHashes[i] = shadowKey !& i

  # Check if we've already generated this shadow
  let shadowKeyBase = shadowKey !& 0
  # let newSize = max(shadowBlur.int + shadowSpread.int + maxRadius.int, 2)
  let newSize = cbs.totalSize

  if shadowKeyBase notin ctx.entries:
    const whiteColor = rgba(255, 255, 255, 255)
    let center = vec2(cbs.totalSize.float32/2, cbs.totalSize.float32/2)
    let corners = vec4(radii[dcBottomLeft], radii[dcTopRight], radii[dcBottomRight], radii[dcTopLeft])
    var shadowImg = newImage(newSize, newSize)
    let wh = if innerShadow: vec2(cbs.inner.float32 - 2*shadowSpread, cbs.inner.float32 - 2*shadowSpread) else: vec2(cbs.inner.float32, cbs.inner.float32)
    let spread = if innerShadow: 0.0 else: shadowSpread

    let mode = if innerShadow: sdfModeInsetShadow else: sdfModeDropShadow
    drawSdfShape(
                shadowImg,
                center = center,
                wh = wh,
                params = RoundedBoxParams(r: corners),
                pos = whiteColor,
                neg = whiteColor,
                factor = shadowBlur,
                spread = spread,
                mode = mode)
    echo "drawing shadow: ", innerShadow, " sz:", rect.w, "x", rect.h, " total:", cbs.totalSize, " inner:", cbs.inner, " padding:", cbs.padding, " side:", cbs.sideSize, " blur: ", shadowBlur, " spread: ", shadowSpread, " maxr:", maxRadius, " -rTL:", radii[dcTopLeft], " -rTR:", radii[dcTopRight], " -rBL:", radii[dcBottomLeft], " -rBR:", radii[dcBottomRight]
    # shadowImg.writeFile("tests/renderer-shadowImage-" & $innerShadow & "-maxr" & $maxRadius & "-totalsz" & $cbs.totalSize & "-sidesz" & $cbs.sideSize & "-blur" & $shadowBlur & "-spread" & $shadowSpread & "-rTL" & $radii[dcTopLeft] & "-rTR" & $radii[dcTopRight] & "-rBL" & $radii[dcBottomLeft] & "-rBR" & $radii[dcBottomRight] & ".png")

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

    # patchArray[0].writeFile("tests/renderer-shadowImage-topleft-" & $innerShadow & "-maxr" & $maxRadius & "-totalsz" & $cbs.totalSize & "-sidesz" & $cbs.sideSize & "-blur" & $shadowBlur & "-spread" & $shadowSpread & "-rTL" & $radii[dcTopLeft] & "-rTR" & $radii[dcTopRight] & "-rBL" & $radii[dcBottomLeft] & "-rBR" & $radii[dcBottomRight] & ".png")

    # if innerShadow:
    #   echo "making inner shadow", " top left hash: ", ninePatchHashes[0], " shadow keybase: ", shadowKeyBase

  var 
    totalPadding = cbs.padding.int
    corner = totalPadding.float32 + cbs.sideSize.float32 + 1
    # corner = totalPadding.float32 + 1

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
  ctx.drawImageAdj(ninePatchHashes[5], rightEdge.xy, shadowColor, rightEdge.wh)
  let bottomEdge = rect( sbox.x + corner, sbox.y + sbox.h - corner, sbox.w - 2 * corner, corner)
  ctx.drawImageAdj(ninePatchHashes[6], bottomEdge.xy, shadowColor, bottomEdge.wh)
  let leftEdge = rect( sbox.x, sbox.y + corner, corner, sbox.h - 2 * corner)
  ctx.drawImageAdj(ninePatchHashes[7], leftEdge.xy, shadowColor, leftEdge.wh)
  
  # Center (stretched both ways)
  if not innerShadow:
    let center = rect(sbox.x + corner, sbox.y + corner, sbox.w - 2 * corner, sbox.h - 2 * corner)
    ctx.drawRect(center, shadowColor)