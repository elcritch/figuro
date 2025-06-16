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
    # maxRadius = max(radii)
    cbs = getCircleBoxSizes(radii, 0.0, 0.0, weight, w, h)
    maxRadius = cbs.maxRadius
    rw = cbs.sideSize.float32
    rh = cbs.sideSize.float32

  let rhash = hash((int(radii[dcTopLeft]), int(radii[dcTopRight]), int(radii[dcBottomRight]), int(radii[dcBottomLeft])))
  let hash = hash((6217, int(rw * 1), int(rh * 1), int(weight * 1), int(cbs.sideSize * 1), doStroke, outerShadowFill)) !& rhash

  block drawCorners:
    var cornerHashes: array[DirectionCorners, Hash]
    for corner in DirectionCorners:
      let qhash = hash((hash, 41, corner.int))
      cornerHashes[corner] = qhash

    if not ctx.hasImage(toKey(cornerHashes[dcTopRight])):
      let circle =
        when defined(figuroNoSDF):
          if doStroke:
            generateCircleBox(radii, stroked = true, lineWidth = weight, outerShadowFill = outerShadowFill)
          else:
            generateCircleBox(radii, stroked = false, lineWidth = weight)
        else:
          block:
            let fill = rgba(255, 255, 255, 255)
            let clear = rgba(0, 0, 0, 0)
            var center = vec2(rw, rh)
            let wh = vec2(2*rw+1, 2*rh+1)
            # let corners = vec4(radii[dcTopRight], radii[dcBottomRight], radii[dcBottomLeft], radii[dcTopLeft])
            let corners = vec4(radii[dcBottomRight], radii[dcTopRight], radii[dcBottomLeft], radii[dcTopLeft])
            let circle = newImage(int(2*rw), int(2*rh))
            # echo "drawing circle: ", doStroke, " sz:", rect.w, "x", rect.h, " ", rw, "x", rh, " weight: ", weight, " r(", radii[dcTopLeft], ",", radii[dcTopRight], ",", radii[dcBottomLeft], ",", radii[dcBottomRight], ")", " rhash: ", rhash, " "
            if doStroke:
              drawSdfShape(circle,
                    center = center,
                    wh = wh,
                    params = RoundedBoxParams(r: corners),
                    pos = fill.to(ColorRGBA),
                    neg = clear.to(ColorRGBA),
                    factor = weight + 0.5,
                    spread = 0.0,
                    mode = sdfModeAnnular)
            else:
              drawSdfShape(circle,
                    center = center,
                    wh = wh,
                    params = RoundedBoxParams(r: corners),
                    pos = fill.to(ColorRGBA),
                    neg = clear.to(ColorRGBA),
                    mode = sdfModeClipAA)
            # circle.writeFile("tests/circlebox-" & "stroke-" & $doStroke & "-rect" & $rw & "x" & $rh & "-mr" & $maxRadius & ".png")
            circle

      let patches = sliceToNinePatch(circle)
      # Store each piece in the atlas
      let cornerImages: array[DirectionCorners, Image] = [
        dcTopLeft: patches.topLeft,
        dcTopRight: patches.topRight, 
        dcBottomLeft: patches.bottomLeft,
        dcBottomRight: patches.bottomRight,
      ]

      for corner in DirectionCorners:
        let img = cornerImages[corner]
        ctx.addImage(toKey(cornerHashes[corner]), img)

    let
      xy = rect.xy
      offsets: array[DirectionCorners, Vec2] = [
        dcTopLeft: vec2(0, 0),
        dcTopRight: vec2(w - rw, 0),
        dcBottomLeft: vec2(0, h - rh),
        dcBottomRight: vec2(w - rw, h - rh),
      ]

    for corner in DirectionCorners:
      let
        pt = ceil(xy + offsets[corner])

      ctx.drawImage(toKey(cornerHashes[corner]), pt, color)

  block drawEdgeBoxes:
    let
      ww = if doStroke: weight else: cbs.sideSize.float32
      # ww = cbs.sideSize.float32
      rrw = if doStroke: w - weight else: w - rw
      rrh = if doStroke: h - weight else: h - rh
      wrw = w - 2 * rw
      hrh = h - 2 * rh

    if not doStroke:
      ctx.drawRect(rect(ceil(rect.x + rw), ceil(rect.y + rh), wrw, hrh), color)

    ctx.drawRect(rect(ceil(rect.x + rw), ceil(rect.y), wrw, ww), color)
    ctx.drawRect(rect(ceil(rect.x + rw), ceil(rect.y + rrh), wrw, ww), color)

    ctx.drawRect(rect(ceil(rect.x), ceil(rect.y + rh), ww, hrh), color)
    ctx.drawRect(rect(ceil(rect.x + rrw), ceil(rect.y + rh), ww, hrh), color)
