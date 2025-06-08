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
    maxRadius = max(radii)
    rw = maxRadius
    rh = maxRadius

  let hash =
    hash((6217, (rw * 10).int, (rh * 10).int, hash(radii), (weight * 10).int, doStroke))

  block drawCorners:
    var hashes: array[DirectionCorners, Hash]
    for quadrant in DirectionCorners:
      let qhash = hash !& hash(19) !& quadrant.int
      hashes[quadrant] = qhash
    var sideHashes: array[Directions, Hash]
    for side in Directions:
      let shash = hash !& hash(23) !& side.int
      sideHashes[side] = shash

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
            let wh = vec2(2*rw, 2*rh)
            # let corners = vec4(radii[dcTopRight], radii[dcBottomRight], radii[dcBottomLeft], radii[dcTopLeft])
            # let corners = vec4(radii[dcBottomRight], radii[dcTopRight], radii[dcBottomLeft], radii[dcTopLeft])
            let corners = vec4(radii[dcBottomLeft], radii[dcTopRight], radii[dcBottomRight], radii[dcTopLeft])
            let cbs = getCircleBoxSizes(radii, 0.0, 0.0)
            let circle = newImage(cbs.totalSize, cbs.totalSize)
            if doStroke:
              drawSdfShape(circle,
                    center = center,
                    wh = wh,
                    params = RoundedBoxParams(r: corners),
                    pos = fill.to(ColorRGBA),
                    neg = clear.to(ColorRGBA),
                    factor = 5.5,
                    spread = 0.0,
                    mode = sdfModeAnnular)
            else:
              drawSdfShape(circle,
                    center = center,
                    wh = wh,
                    params = RoundedBoxParams(r: corners),
                    pos = fill.to(ColorRGBA),
                    neg = clear.to(ColorRGBA),
                    factor = 5.5,
                    spread = 0.0,
                    mode = sdfModeClipAA)
            circle.writeFile("tests/circlebox-" & "stroke-" & $doStroke & "-rect" & $rect.w & "x" & $rect.h & ".png")
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

      let sidePatchArray = [
        dTop: patches.top,
        dRight: patches.right,
        dBottom: patches.bottom,
        dLeft: patches.left,
      ]

      for side in Directions:
        let img = sidePatchArray[side]
        ctx.addImage(toKey(sideHashes[side]), img)

        img.writeFile("tests/circlebox-side-" & $side & "-stroke-" & $doStroke & "-rect" & $rect.w & "x" & $rect.h & ".png")

    let
      xy = rect.xy
      offsets = [
        dcTopLeft: vec2(0, 0),
        dcTopRight: vec2(w - rw, 0),
        dcBottomRight: vec2(w - rw, h - rh),
        dcBottomLeft: vec2(0, h - rh),
      ]
      sideOffsets = [
        dTop: vec2(rw, 0),
        dRight: vec2(w - rw, rh),
        dBottom: vec2(w - rw, h - rh),
        dLeft: vec2(0, h - rh),
      ]

    for corner in DirectionCorners:
      let
        pt = ceil(xy + offsets[corner])

      ctx.drawImage(toKey(hashes[corner]), pt, color)
    
    for side in Directions:
      let
        pt = ceil(xy + sideOffsets[side])
      ctx.drawImage(toKey(sideHashes[side]), pt, color)

  block drawEdgeBoxes:
    let
      ww = if doStroke: weight else: maxRadius
      rrw = if doStroke: w - weight else: w - rw
      rrh = if doStroke: h - weight else: h - rh
      wrw = w - 2 * rw
      hrh = h - 2 * rh

    if not doStroke:
      ctx.drawRect(rect(ceil(rect.x + rw + 1), ceil(rect.y + rh + 1), wrw, hrh), color)

    when defined(figuroNoSDF):
      ctx.drawRect(rect(ceil(rect.x + rw), ceil(rect.y), wrw, ww), color)
      ctx.drawRect(rect(ceil(rect.x + rw), ceil(rect.y + rrh), wrw, ww), color)

      ctx.drawRect(rect(ceil(rect.x), ceil(rect.y + rh), ww, hrh), color)
      ctx.drawRect(rect(ceil(rect.x + rrw), ceil(rect.y + rh), ww, hrh), color)
