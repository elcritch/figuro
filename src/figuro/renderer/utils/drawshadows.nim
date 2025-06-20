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

  if cbs.paddingOffset == 0:
    return

  let cornerCbs = cbs.roundedBoxCornerSizes(radii, innerShadow)

  var sideHashes: array[Directions, Hash]
  for side in Directions:
    sideHashes[side] = hash((shadowKey, 971767, int(cbs.padding)))

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
      let wh = vec2(2*cornerCbs.inner.float32, 2*cornerCbs.inner.float32)

      let spread = shadowSpread
      let mode = if innerShadow: sdfModeInsetShadow else: sdfModeDropShadow

      var shadowImg = newImage(cornerCbs.sideSize, cornerCbs.sideSize)

      drawSdfShape(shadowImg,
                  center = vec2(cornerCbs.center.float32),
                  wh = wh,
                  params = RoundedBoxParams(r: corners),
                  pos = whiteColor,
                  neg = whiteColor,
                  factor = shadowBlur,
                  spread = spread,
                  mode = mode)
      if innerShadow:
        shadowImg.writeFile("examples/shadow-" & $corner & "-radius" & $cornerCbs.radius & ".png")
      ctx.putImage(cornerHashes[corner], shadowImg)

    for side in Directions:
      if sideHashes[side] in ctx.entries or cbs.paddingOffset == 0:
        continue

      let corners = vec4(0)
      var shadowImg = newImage(cbs.paddingOffset, 4)
      let wh = vec2(1, 12)

      let spread = if innerShadow: 0.0 else: shadowSpread
      let mode = if innerShadow: sdfModeInsetShadow else: sdfModeDropShadow

      drawSdfShape(shadowImg,
                  center = vec2(cbs.paddingOffset.float32, 2),
                  wh = wh,
                  params = RoundedBoxParams(r: corners),
                  pos = whiteColor,
                  neg = whiteColor,
                  factor = shadowBlur,
                  spread = spread,
                  mode = mode)
      ctx.putImage(sideHashes[side], shadowImg)

    let
      xy = rect.xy
      zero = vec2(0, 0)
      cornerSize = vec2(bw, bh)
      padding = cbs.padding.float32
      paddingOffset = cbs.paddingOffset.float32

      cpos = [
        dcTopLeft: xy + vec2(0, 0),
        dcTopRight: xy + vec2(w - cornerCbs[dcTopRight].inner.float32, 0),
        dcBottomLeft: xy + vec2(0, h - cornerCbs[dcBottomLeft].inner.float32),
        dcBottomRight: xy + vec2(w - cornerCbs[dcBottomRight].inner.float32,
                                 h - cornerCbs[dcBottomRight].inner.float32)
      ]

      coffset = [
        dcTopLeft: vec2(-paddingOffset, -paddingOffset),
        dcTopRight: vec2(0, -paddingOffset),
        dcBottomLeft: vec2(-paddingOffset, 0),
        dcBottomRight: vec2(0, 0)
      ]

      ccenter = [
        dcTopLeft: vec2(cornerCbs[dcTopLeft].sideSize.float32, cornerCbs[dcTopLeft].sideSize.float32),
        dcTopRight: vec2(cornerCbs[dcTopRight].sideSize.float32, cornerCbs[dcTopRight].sideSize.float32),
        dcBottomLeft: vec2(cornerCbs[dcBottomLeft].sideSize.float32, cornerCbs[dcBottomLeft].sideSize.float32),
        dcBottomRight: vec2(cornerCbs[dcBottomRight].sideSize.float32, cornerCbs[dcBottomRight].sideSize.float32)
      ]

      darkGrey = rgba(50, 50, 50, 255).to(Color)
      black = rgba(0, 0, 0, 255).to(Color)

      angles = [dcTopLeft: 0.0, dcTopRight: -Pi/2, dcBottomLeft: Pi/2, dcBottomRight: Pi]

    let sides = [dcTopLeft: dLeft, dcTopRight: dTop, dcBottomLeft: dBottom, dcBottomRight: dRight]
    let prevCorner = [dcTopLeft: dcBottomLeft, dcTopRight: dcTopLeft, dcBottomLeft: dcBottomRight, dcBottomRight: dcTopRight]

    for corner in DirectionCorners:
      ctx.saveTransform()
      ctx.translate(floor(cpos[corner] + coffset[corner] + ccenter[corner] / 2)) # important, floor once here, not after
      ctx.rotate(angles[corner])
      ctx.translate((-ccenter[corner] / 2))
      ctx.drawImage(cornerHashes[corner], zero, shadowColor)

      let sideAdj = (maxRadius.float32 - cornerCbs[corner].inner.float32)
      let inner = cornerCbs[corner].inner.float32
      let sideDelta = cornerCbs[corner].sideDelta.float32
      let sideSize = cornerCbs[corner].sideSize.float32

      if cornerCbs[corner].sideDelta > 0:
        # inner patch left, right, and then center
        if innerShadow:
          discard
          # ctx.drawRect(rect(0, inner, cbs.weightSize.float32, sideDelta), color)
          # ctx.drawRect(rect(inner, 0, sideDelta, cbs.weightSize.float32), color)
        else:
          ctx.drawRect(rect(paddingOffset, paddingOffset + inner, inner, sideDelta), shadowColor)
          ctx.drawRect(rect(paddingOffset + inner, paddingOffset, sideDelta, cbs.maxRadius.float32), shadowColor)

      let borderDim = if sides[corner] in [dTop, dBottom]: w else: h
      let prevSideAdj = (maxRadius.float32 - cornerCbs[prevCorner[corner]].inner.float32)
      let borderSize = vec2(paddingOffset, borderDim - 2*maxRadius.float32 + sideAdj + prevSideAdj)
      ctx.drawImageAdj(sideHashes[sides[corner]], vec2(0, cornerCbs[corner].sideSize.float32), shadowColor, borderSize)
      ctx.restoreTransform()

    if innerShadow:
      # left and right side boxes
      ctx.drawRect(rect(rect.x, rect.y + maxRadius.float32, maxRadius.float32, h - 2*maxRadius.float32), shadowColor)
      ctx.drawRect(rect(rect.x + w - maxRadius.float32, rect.y + maxRadius.float32, maxRadius.float32, h - 2*maxRadius.float32), shadowColor)

      # top and bottom side boxes
      ctx.drawRect(rect(rect.x + maxRadius.float32, rect.y, w - 2*maxRadius.float32, maxRadius.float32), shadowColor)
      ctx.drawRect(rect(rect.x + maxRadius.float32, rect.y + h - maxRadius.float32, w - 2*maxRadius.float32, maxRadius.float32), shadowColor)
    else:
      ctx.drawRect(rect(rect.x + maxRadius.float32, rect.y, w - 2*maxRadius.float32, h), shadowColor)
      ctx.drawRect(rect(rect.x, rect.y + maxRadius.float32, maxRadius.float32, h - 2*maxRadius.float32), shadowColor)
      ctx.drawRect(rect(rect.x + w - maxRadius.float32, rect.y + maxRadius.float32, maxRadius.float32, h - 2*maxRadius.float32), shadowColor)
