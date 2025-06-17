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

proc toHex*(h: Hash): string =
  const HexChars = "0123456789ABCDEF"
  result = newString(sizeof(Hash) * 2)
  var h = h
  for i in countdown(result.high, 0):
    result[i] = HexChars[h and 0xF]
    h = h shr 4


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

  # let hash = hash((6217, int(cbs.sideSize), int(cbs.maxRadius), int(weight), doStroke, outerShadowFill))
  let hash = hash((6217, doStroke, outerShadowFill, cbs.padding, cbs.weightSize))
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

      let cornerCbs = cornerCbs[corner]
      let corners = vec4(cornerCbs.radius.float32)
      var image = newImage(cornerCbs.sideSize, cornerCbs.sideSize)
      let wh = vec2(2*cornerCbs.sideSize.float32, 2*cornerCbs.sideSize.float32)

      if doStroke:
        drawSdfShape(image,
              center = vec2(cornerCbs.center.float32, cornerCbs.center.float32),
              wh = wh,
              params = RoundedBoxParams(r: corners),
              pos = fill.to(ColorRGBA),
              neg = clear.to(ColorRGBA),
              factor = cbs.weightSize.float32,
              spread = 0.0,
              mode = sdfModeAnnular)
      else:
        drawSdfShape(image,
              center = vec2(cornerCbs.center.float32, cornerCbs.center.float32),
              wh = wh,
              params = RoundedBoxParams(r: corners),
              pos = fill.to(ColorRGBA),
              neg = clear.to(ColorRGBA),
              mode = sdfModeClipAA)

      if color.a != 1.0:
        var msg = "corner"
        msg &= (if doStroke: "-stroke" else: "-noStroke") 
        msg &= "-weight" & $weight 
        msg &= "-radius" & $cornerCbs.radius 
        msg &= "-sideSize" & $cornerCbs.sideSize 
        msg &= "-wh" & $wh.x 
        msg &= "-padding" & $cbs.padding 
        msg &= "-center" & $cornerCbs.center 
        msg &= "-doStroke" & (if doStroke: "true" else: "false") 
        msg &= "-outerShadowFill" & (if outerShadowFill: "true" else: "false")
        msg &= "-corner-" & $corner 
        msg &= "-hash" & toHex(cornerHashes[corner])
        echo "generating corner: ", msg
        image.writeFile("examples/" & msg & ".png")
      ctx.putImage(toKey(cornerHashes[corner]), image)

    let
      xy = rect.xy
      zero = vec2(0, 0)
      cornerSize = vec2(bw, bh)
      topLeft = xy + vec2(0, 0)
      topRight = xy + vec2(w - bw + cornerCbs[dcTopRight].sideDelta.float32, 0)
      bottomLeft = xy + vec2(0, h - bh + cornerCbs[dcBottomLeft].sideDelta.float32)
      bottomRight = xy + vec2(w - bw + cornerCbs[dcBottomRight].sideDelta.float32,
                              h - bh + cornerCbs[dcBottomRight].sideDelta.float32)

      tlCornerSize = vec2(0.0, 0.0)
      trCornerSize = vec2(cornerCbs[dcTopRight].sideSize.float32, cornerCbs[dcTopRight].sideSize.float32)
      blCornerSize = vec2(cornerCbs[dcBottomLeft].sideSize.float32, cornerCbs[dcBottomLeft].sideSize.float32)
      brCornerSize = vec2(cornerCbs[dcBottomRight].sideSize.float32, cornerCbs[dcBottomRight].sideSize.float32)

      darkGrey = rgba(50, 50, 50, 255).to(Color)

    if color.a != 1.0:
      echo "drawing corners: ", "BL: " & toHex(cornerHashes[dcBottomLeft]) & " color: " & $color & " hasImage: " & $ctx.hasImage(cornerHashes[dcBottomLeft]) & " cornerSize: " & $blCornerSize & " blPos: " & $(bottomLeft + blCornerSize / 2) & " delta: " & $cornerCbs[dcBottomLeft].sideDelta & " doStroke: " & $doStroke

    ctx.saveTransform()
    ctx.translate(topLeft + tlCornerSize / 2)
    ctx.drawImage(cornerHashes[dcTopLeft], zero, darkGrey)
    ctx.translate(-tlCornerSize / 2)
    ctx.restoreTransform()

    ctx.saveTransform()
    ctx.translate(topRight + trCornerSize / 2)
    ctx.rotate(-Pi/2)
    ctx.translate(-trCornerSize / 2)
    ctx.drawImage(cornerHashes[dcTopRight], zero, darkGrey)
    ctx.restoreTransform()

    ctx.saveTransform()
    # ctx.translate(bottomLeft)
    ctx.translate(bottomLeft + blCornerSize / 2)
    ctx.rotate(Pi/2)
    ctx.translate(-blCornerSize / 2)
    ctx.drawImage(cornerHashes[dcBottomLeft], zero, darkGrey)
    # ctx.drawImage(cornerHashes[dcBottomLeft], zero, rgba(0, 0, 0, 255).to(Color))
    ctx.restoreTransform()

    ctx.saveTransform()
    ctx.translate(bottomRight + brCornerSize / 2)
    ctx.rotate(Pi)
    ctx.translate(-brCornerSize / 2)
    ctx.drawImage(cornerHashes[dcBottomRight], zero, darkGrey)
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