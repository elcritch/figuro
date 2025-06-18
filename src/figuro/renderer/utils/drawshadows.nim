# import glcommons
import std/hashes

import ../../commons
import ../../common/nodes/render

import pkg/chroma
import pkg/sigils
import pkg/chronicles
import pkg/pixie
import pkg/sdfy

import ../utils/drawextras
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
  let 
    w = rect.w.ceil()
    h = rect.h.ceil()
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
    wh = vec2(cbs.inner.float32, cbs.inner.float32)
    bw = cbs.sideSize.float32
    bh = cbs.sideSize.float32

    shadowKey = hash((7723, shadowBlur.int, shadowSpread.int, innerShadow))
  
  let cornerCbs = cbs.roundedBoxCornerSizes(radii)

  var sideHashes: array[Directions, Hash]
  for side in Directions:
    sideHashes[side] = hash((shadowKey, 971767, int(side)))

  block drawCorners:
    var cornerHashes: array[DirectionCorners, Hash]
    for corner in DirectionCorners:
      cornerHashes[corner] = hash((shadowKey, 2474431, int(radii[corner])))

    # use the left side of the shadow key to check if we've already generated this shadow
    const whiteColor = rgba(255, 255, 255, 255)

    for corner in DirectionCorners:
      if cornerHashes[corner] in ctx.entries:
        continue

      let cornerCbs = cornerCbs[corner]
      let corners = vec4(cornerCbs.radius.float32)
      var shadowImg = newImage(cornerCbs.sideSize, cornerCbs.sideSize)
      let wh = vec2(2*cornerCbs.inner.float32, 2*cornerCbs.inner.float32)

      let spread = if innerShadow: 0.0 else: shadowSpread
      let mode = if innerShadow: sdfModeInsetShadow else: sdfModeDropShadow

      drawSdfShape(shadowImg,
                  center = vec2(cornerCbs.center.float32),
                  wh = wh,
                  params = RoundedBoxParams(r: corners),
                  pos = whiteColor,
                  neg = whiteColor,
                  factor = shadowBlur,
                  spread = spread,
                  mode = mode)

      if true:
        var msg = "shadow"
        msg &= (if innerShadow: "inner" else: "outer")
        msg &= "-weight" & $shadowBlur 
        msg &= "-radius" & $cornerCbs.radius 
        msg &= "-sideSize" & $cornerCbs.sideSize 
        msg &= "-wh" & $wh.x 
        msg &= "-padding" & $cbs.padding 
        msg &= "-center" & $cornerCbs.center 
        msg &= "-corner-" & $corner 
        msg &= "-hash" & toHex(cornerHashes[corner])
        echo "generating shadow: ", msg
        shadowImg.writeFile("examples/" & msg & ".png")

      ctx.putImage(cornerHashes[corner], shadowImg)

    var 
      totalPadding = (cbs.totalSize.float32 - cbs.inner.float32) / 2
      corner = totalPadding.float32 + cbs.inner.float32 / 2

    let
      xy = rect.xy
      zero = vec2(0, 0)
      cornerSize = vec2(bw, bh)
      padding = cbs.padding.float32
      paddingOffset = cbs.paddingOffset.float32

      cpos = [
        dcTopLeft: xy + vec2(0, 0),
        dcTopRight: xy + vec2(w - bw, 0),
        dcBottomLeft: xy + vec2(0, h - bh),
        dcBottomRight: xy + vec2(w - bw, h - bh)
      ]

      coffset = [
        dcTopLeft: vec2(-paddingOffset, -paddingOffset),
        dcTopRight: vec2(0, -paddingOffset),
        dcBottomLeft: vec2(-paddingOffset, 0),
        dcBottomRight: vec2(0, 0)
      ]

      csizes = [
        dcTopLeft: vec2(0.0, 0.0),
        dcTopRight: vec2(cornerCbs[dcTopRight].sideSize.float32, cornerCbs[dcTopRight].sideSize.float32),
        dcBottomLeft: vec2(cornerCbs[dcBottomLeft].sideSize.float32, cornerCbs[dcBottomLeft].sideSize.float32),
        dcBottomRight: vec2(cornerCbs[dcBottomRight].sideSize.float32, cornerCbs[dcBottomRight].sideSize.float32)
      ]

      darkGrey = rgba(50, 50, 50, 255).to(Color)

      angles = [dcTopLeft: 0.0, dcTopRight: -Pi/2, dcBottomLeft: Pi/2, dcBottomRight: Pi]

    # if color.a != 1.0:
    #   echo "drawing corners: ", "BL: " & toHex(cornerHashes[dcBottomLeft]) & " color: " & $color & " hasImage: " & $ctx.hasImage(cornerHashes[dcBottomLeft]) & " cornerSize: " & $blCornerSize & " blPos: " & $(bottomLeft + blCornerSize / 2) & " delta: " & $cornerCbs[dcBottomLeft].sideDelta & " doStroke: " & $doStroke

    for corner in DirectionCorners:
      ctx.saveTransform()
      ctx.translate(cpos[corner] + coffset[corner] + csizes[corner] / 2)
      ctx.rotate(angles[corner])
      ctx.translate(-csizes[corner] / 2)
      ctx.drawImage(cornerHashes[corner], zero, shadowColor)

      if false and cornerCbs[corner].sideDelta > 0:
        let inner = cornerCbs[corner].inner.float32
        let sideDelta = cornerCbs[corner].sideDelta.float32
        let sideSize = cornerCbs[corner].sideSize.float32
        # inner patch left, right, and then center
        if innerShadow:
          discard
          # ctx.drawRect(rect(0, inner, cbs.weightSize.float32, sideDelta), color)
          # ctx.drawRect(rect(inner, 0, sideDelta, cbs.weightSize.float32), color)
        else:
          ctx.drawRect(rect(0, inner, inner, sideDelta), shadowColor)
          ctx.drawRect(rect(inner, 0, sideDelta, sideSize), shadowColor)
          # we could do two boxes, but this matches our shadow needs
          ctx.drawRect(rect(inner, inner, sideDelta, sideDelta), shadowColor)

      ctx.restoreTransform()

  block drawEdges:
    discard
    # # Draw edges
    # # Top edge (stretched horizontally)
    # let
    #   topEdge = rect(sbox.x + corner, sbox.y, sbox.w - 2 * corner, corner)
    #   rightEdge = rect( sbox.x + sbox.w - corner, sbox.y + corner, corner, sbox.h - 2 * corner)
    #   bottomEdge = rect( sbox.x + corner, sbox.y + sbox.h - corner, sbox.w - 2 * corner, corner)
    #   leftEdge = rect( sbox.x, sbox.y + corner, corner, sbox.h - 2 * corner)

    # ctx.drawImageAdj(sideHashes[dTop], topEdge.xy, shadowColor, topEdge.wh)
    # ctx.drawImageAdj(sideHashes[dRight], rightEdge.xy, shadowColor, rightEdge.wh)
    # ctx.drawImageAdj(sideHashes[dBottom], bottomEdge.xy, shadowColor, bottomEdge.wh)
    # ctx.drawImageAdj(sideHashes[dLeft], leftEdge.xy, shadowColor, leftEdge.wh)
    
    # # Center (stretched both ways)
    # if not innerShadow:
    #   let center = rect(sbox.x + corner, sbox.y + corner, sbox.w - 2 * corner, sbox.h - 2 * corner)
    #   ctx.drawRect(center, shadowColor)