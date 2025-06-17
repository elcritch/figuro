import pkg/pixie
import pkg/chroma
import pkg/sdfy

import ../../common/nodes/basics
import ./drawutils
import ./drawextras

proc drawOuterBox*[R](ctx: R, rect: Rect, padding: float32, color: Color) =

    var obox = rect
    obox.xy = obox.xy - vec2(padding, padding)
    obox.wh = obox.wh + vec2(2*padding, 2*padding)
    let xy = obox.xy
    let rectTop = rect(xy, vec2(obox.w, padding))
    let rectLeft = rect(xy + vec2(0, padding), vec2(padding, obox.h - 2*padding))
    let rectBottom = rect(xy + vec2(0, obox.h - padding), vec2(obox.w, padding))
    let rectRight = rect(xy + vec2(obox.w - padding, padding), vec2(padding, obox.h - 2*padding))

    ctx.drawRect(rectTop, color)
    ctx.drawRect(rectLeft, color)
    ctx.drawRect(rectBottom, color)
    ctx.drawRect(rectRight, color)

proc drawRoundedRect*[R](
    ctx: R,
    rect: Rect,
    color: Color,
    radii: array[DirectionCorners, float32],
    weight: float32 = -1.0,
    doStroke: bool = false,
    outerShadowFill: bool = false,
) =
  mixin toKey, hasImage, addImage

  if rect.w <= 0 or rect.h <= -0:
    return

  let
    w = rect.w.ceil()
    h = rect.h.ceil()
    radii = clampRadii(radii, rect)
    cbs = getCircleBoxSizes(radii, 0.0, 0.0, weight, w, h)
    maxRadius = cbs.maxRadius
    bw = cbs.sideSize.float32
    bh = cbs.sideSize.float32

  let hash = hash((6217, int(cbs.sideSize), int(cbs.maxRadius), int(weight), doStroke, outerShadowFill))
  let cornerCbs = cbs.roundedBoxCornerSizes(radii)

  block drawCorners:
    var cornerHashes: array[DirectionCorners, Hash]
    for corner in DirectionCorners:
      cornerHashes[corner] = hash((hash, 41, int(radii[corner])))

    let fill = rgba(255, 255, 255, 255)
    let clear = rgba(0, 0, 0, 0)

    for corner in DirectionCorners:
      if cornerHashes[corner] in ctx.entries:
        continue

      var image = newImage(int(2*bw), int(2*bh))
      let cornerCbs = cornerCbs[corner]
      let corners = [cornerCbs.radius, cornerCbs.radius, cornerCbs.radius, cornerCbs.radius]

      if doStroke:
        drawSdfShape(image,
              center = vec2(cornerCbs.center, cornerCbs.center),
              wh = vec2(cornerCbs.sideSize, cornerCbs.sideSize),
              params = RoundedBoxParams(r: corners),
              pos = fill.to(ColorRGBA),
              neg = clear.to(ColorRGBA),
              factor = weight + 0.5,
              spread = 0.0,
              mode = sdfModeAnnular)
      else:
        drawSdfShape(image,
              center = vec2(cornerCbs.center, cornerCbs.center),
              wh = vec2(cornerCbs.sideSize, cornerCbs.sideSize),
              params = RoundedBoxParams(r: corners),
              pos = fill.to(ColorRGBA),
              neg = clear.to(ColorRGBA),
              mode = sdfModeClipAA)

      ctx.putImage(toKey(cornerHashes[corner]), image)

    let
      xy = rect.xy
      zero = vec2(0, 0)
      cornerSize = vec2(bw, bh)
      topLeft = xy + vec2(0, 0)
      topRight = xy + vec2(w - bw, 0)
      bottomLeft = xy + vec2(0, h - bh)
      bottomRight = xy + vec2(w - bw, h - bh)

    ctx.saveTransform()
    ctx.translate(topLeft)
    ctx.drawImage(cornerHashes[dcTopLeft], zero, color)
    ctx.restoreTransform()

    ctx.saveTransform()
    ctx.translate(topRight + cornerSize / 2)
    ctx.rotate(-Pi/2)
    ctx.translate(-cornerSize / 2)
    ctx.drawImage(cornerHashes[dcTopRight], zero, color)
    ctx.restoreTransform()

    ctx.saveTransform()
    ctx.translate(bottomLeft + cornerSize / 2)
    ctx.rotate(Pi/2)
    ctx.translate(-cornerSize / 2)
    ctx.drawImage(cornerHashes[dcBottomLeft], zero, color)
    ctx.restoreTransform()

    ctx.saveTransform()
    ctx.translate(bottomRight + cornerSize / 2)
    ctx.rotate(Pi)
    ctx.translate(-cornerSize / 2)
    ctx.drawImage(cornerHashes[dcBottomRight], zero, color)
    ctx.restoreTransform()

  block drawEdgeBoxes:
    let
      ww = if doStroke: weight else: cbs.sideSize.float32
      # ww = cbs.sideSize.float32
      rrw = if doStroke: w - weight else: w - bw
      rrh = if doStroke: h - weight else: h - bh
      wrw = w - 2 * bw
      hrh = h - 2 * bh

    if not doStroke:
      ctx.drawRect(rect(ceil(rect.x + bw), ceil(rect.y + bh), wrw, hrh), color)

    ctx.drawRect(rect(ceil(rect.x + bw), ceil(rect.y), wrw, ww), color)
    ctx.drawRect(rect(ceil(rect.x + bw), ceil(rect.y + rrh), wrw, ww), color)

    ctx.drawRect(rect(ceil(rect.x), ceil(rect.y + bh), ww, hrh), color)
    ctx.drawRect(rect(ceil(rect.x + rrw), ceil(rect.y + bh), ww, hrh), color)