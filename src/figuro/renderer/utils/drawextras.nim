# import glcommons
import std/hashes

import ../../commons
import ../../common/nodes/render

import pkg/chroma
import pkg/sigils
import pkg/chronicles

import ../utils/boxes

proc hash(v: Vec2): Hash =
  hash((v.x, v.y))

proc hash(radii: array[DirectionCorners, float32]): Hash =
  for r in radii:
    result = result !& hash(r)

proc clampRadii*(radii: array[DirectionCorners, float32], rect: Rect): array[DirectionCorners, float32] =
  result = radii
  for r in result.mitems():
    r = max(1.0, min(r, min(rect.w / 2, rect.h / 2))).ceil()

proc drawOuterBox*[R](bxy: R, rect: Rect, padding: float32, color: Color) =

    var obox = rect
    obox.xy = obox.xy - vec2(padding, padding)
    obox.wh = obox.wh + vec2(2*padding, 2*padding)
    let xy = obox.xy
    let rectTop = rect(xy, vec2(obox.w, padding))
    let rectLeft = rect(xy + vec2(0, padding), vec2(padding, obox.h - 2*padding))
    let rectBottom = rect(xy + vec2(0, obox.h - padding), vec2(obox.w, padding))
    let rectRight = rect(xy + vec2(obox.w - padding, padding), vec2(padding, obox.h - 2*padding))

    bxy.drawRect(rectTop, color)
    bxy.drawRect(rectLeft, color)
    bxy.drawRect(rectBottom, color)
    bxy.drawRect(rectRight, color)

proc drawRoundedRect*[R](
    bxy: R,
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
      let qhash = hash !& quadrant.int
      hashes[quadrant] = qhash

    if not bxy.hasImage(toKey(hashes[dcTopRight])):
      let circle =
        if doStroke:
          generateCircleBox(radii, stroked = true, lineWidth = weight, outerShadowFill = outerShadowFill)
        else:
          generateCircleBox(radii, stroked = false, lineWidth = weight)

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
        bxy.addImage(toKey(hashes[quadrant]), img)

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

      bxy.drawImage(toKey(hashes[corner]), pt, color)

  block drawEdgeBoxes:
    let
      ww = if doStroke: weight else: maxRadius
      rrw = if doStroke: w - weight else: w - rw
      rrh = if doStroke: h - weight else: h - rh
      wrw = w - 2 * rw
      hrh = h - 2 * rh

    if not doStroke:
      bxy.drawRect(rect(ceil(rect.x + rw), ceil(rect.y + rh), wrw, hrh), color)

    bxy.drawRect(rect(ceil(rect.x + rw), ceil(rect.y), wrw, ww), color)
    bxy.drawRect(rect(ceil(rect.x + rw), ceil(rect.y + rrh), wrw, ww), color)

    bxy.drawRect(rect(ceil(rect.x), ceil(rect.y + rh), ww, hrh), color)
    bxy.drawRect(rect(ceil(rect.x + rrw), ceil(rect.y + rh), ww, hrh), color)
