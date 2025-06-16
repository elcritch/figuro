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
  proc getShadowKey(blur: float32, spread: float32, totalSize: int, innerShadow: bool, radii: array[DirectionCorners, float32]): Hash =
    result = hash((7723, blur.int, spread.int, innerShadow, totalSize))

  proc getShadowKey(shadowKey: Hash, radii: array[DirectionCorners, float32], corner: DirectionCorners): Hash =
    result = hash((shadowKey, 2474431, int(radii[corner])))

  proc getShadowKey(shadowKey: Hash, radii: array[Directions, float32], side: Directions): Hash =
    result = hash((shadowKey, 971767, int(side)))

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
    shadowKey = getShadowKey(shadowBlur, shadowSpread, cbs.totalSize, innerShadow, radii)
    wh = vec2(cbs.inner.float32, cbs.inner.float32)
  
  var cornerHashes: array[DirectionCorners, Hash]
  for corner in DirectionCorners:
    cornerHashes[corner] = getShadowKey(shadowKey, radii, corner)

  var sideHashes: array[Directions, Hash]
  for side in Directions:
    sideHashes[side] = getShadowKey(shadowKey, radii, side)

  # use the left side of the shadow key to check if we've already generated this shadow
  let newSize = cbs.totalSize
  let shadowKeyLeft = getShadowKey(shadowKey, radii, dLeft)
  var missingAnyCorner = false
  for corner in DirectionCorners:
    if cornerHashes[corner] notin ctx.entries:
      missingAnyCorner = true
      break

  if shadowKeyLeft notin ctx.entries or missingAnyCorner:
    let corners = radii.cornersToSdfRadii()
    const whiteColor = rgba(255, 255, 255, 255)
    let center = vec2(cbs.totalSize.float32/2, cbs.totalSize.float32/2)
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

    # Slice it into 9-patch pieces
    let patches = sliceToNinePatch(shadowImg)

    let cornerArray = [
      dcTopLeft: patches.topLeft,
      dcTopRight: patches.topRight, 
      dcBottomLeft: patches.bottomLeft,
      dcBottomRight: patches.bottomRight,
    ]
    let sideArray = [
      dTop: patches.top,
      dRight: patches.right,
      dBottom: patches.bottom,
      dLeft: patches.left,
    ]

    for corner in DirectionCorners:
      let cornerHash = cornerHashes[corner]
      if cornerHash notin ctx.entries:
        let image = cornerArray[corner]
        case corner:
        of dcTopLeft:
          discard
        of dcTopRight:
          image.flipHorizontal()
        of dcBottomRight:
          image.flipHorizontal()
          image.flipVertical()
        of dcBottomLeft:
          image.flipVertical()
        
        ctx.putImage(cornerHash, image)

    for side in Directions:
      let sideHash = getShadowKey(shadowKey, radii, side)
      ctx.putImage(sideHash, sideArray[side])

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
    zero = vec2(0, 0)
    topLeft = rect(sbox.x, sbox.y, corner, corner)
    topRight = rect(sbox.x + sbox.w - corner, sbox.y, corner, corner)
    bottomLeft = rect(sbox.x, sbox.y + sbox.h - corner, corner, corner)
    bottomRight = rect(sbox.x + sbox.w - corner, sbox.y + sbox.h - corner, corner, corner)
  
  # Draw corners

  ctx.drawImageAdj(cornerHashes[dcTopLeft], topLeft.xy, shadowColor, topLeft.wh)

  ctx.saveTransform()
  # ctx.translate(vec2(+topRight.w/2, topRight.h/2))
  ctx.translate(topRight.xy + topRight.wh / 2)
  ctx.rotate(-Pi/2)
  ctx.translate(-topRight.wh / 2)
  ctx.drawImageAdj(cornerHashes[dcTopRight], zero, shadowColor, topRight.wh)
  ctx.restoreTransform()

  ctx.saveTransform()
  ctx.translate(bottomLeft.xy + bottomLeft.wh / 2)
  ctx.rotate(Pi/2)
  ctx.translate(-bottomLeft.wh / 2)
  ctx.drawImageAdj(cornerHashes[dcBottomLeft], zero, shadowColor, bottomLeft.wh)
  ctx.restoreTransform()

  ctx.saveTransform()
  ctx.translate(bottomRight.xy + bottomRight.wh / 2)
  ctx.rotate(Pi)
  ctx.translate(-bottomRight.wh / 2)
  ctx.drawImageAdj(cornerHashes[dcBottomRight], zero, shadowColor, bottomRight.wh)
  ctx.restoreTransform()

  # Draw edges
  # Top edge (stretched horizontally)
  let
    topEdge = rect(sbox.x + corner, sbox.y, sbox.w - 2 * corner, corner)
    rightEdge = rect( sbox.x + sbox.w - corner, sbox.y + corner, corner, sbox.h - 2 * corner)
    bottomEdge = rect( sbox.x + corner, sbox.y + sbox.h - corner, sbox.w - 2 * corner, corner)
    leftEdge = rect( sbox.x, sbox.y + corner, corner, sbox.h - 2 * corner)

  ctx.drawImageAdj(sideHashes[dTop], topEdge.xy, shadowColor, topEdge.wh)
  ctx.drawImageAdj(sideHashes[dRight], rightEdge.xy, shadowColor, rightEdge.wh)
  ctx.drawImageAdj(sideHashes[dBottom], bottomEdge.xy, shadowColor, bottomEdge.wh)
  ctx.drawImageAdj(sideHashes[dLeft], leftEdge.xy, shadowColor, leftEdge.wh)
  
  # Center (stretched both ways)
  # if not innerShadow:
  #   let center = rect(sbox.x + corner, sbox.y + corner, sbox.w - 2 * corner, sbox.h - 2 * corner)
  #   ctx.drawRect(center, shadowColor)