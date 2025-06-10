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
    # radii = clampRadii(radii, rect)
    # maxRadius = max(radii)
    cbs = getCircleBoxSizes(radii, 0.0, 0.0, weight, w, h)
    maxRadius = cbs.maxRadius
    rw = cbs.sideSize.float32
    rh = cbs.sideSize.float32

  let hash =
    hash((6217, (rw * 10).int, (rh * 10).int, hash(radii), (weight * 10).int, doStroke))

  block drawCorners:
    var hashes: array[DirectionCorners, Hash]
    for quadrant in DirectionCorners:
      let qhash = hash !& hash(41) !& quadrant.int
      hashes[quadrant] = qhash

    if not ctx.hasImage(toKey(hashes[dcTopRight])):
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
            var center = vec2(rect.x + rw, rect.y + rh)
            let wh = vec2(2*rw+1, 2*rh+1)
            # let corners = vec4(radii[dcTopRight], radii[dcBottomRight], radii[dcBottomLeft], radii[dcTopLeft])
            let corners = vec4(radii[dcBottomLeft], radii[dcTopRight], radii[dcBottomRight], radii[dcTopLeft])
            let circle = newImage(int(2*rw), int(2*rh))
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
      let patchArray = [
        dcTopLeft: patches.topLeft,
        dcTopRight: patches.topRight, 
        dcBottomRight: patches.bottomRight,
        dcBottomLeft: patches.bottomLeft,
      ]

      for quadrant in DirectionCorners:
        let img = patchArray[quadrant]
        ctx.addImage(toKey(hashes[quadrant]), img)

    let
      xy = rect.xy
      offsets = [
        dcTopLeft: vec2(0, 0),
        dcTopRight: vec2(w - rw, 0),
        dcBottomRight: vec2(w - rw, h - rh),
        dcBottomLeft: vec2(0, h - rh),
      ]

    for corner in DirectionCorners:
      let
        pt = ceil(xy + offsets[corner])

      ctx.drawImage(toKey(hashes[corner]), pt, color)

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
