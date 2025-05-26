import glcommons

import pkg/chroma
import pkg/sigils
import pkg/chronicles
import pkg/boxy

import ../utils/boxes

proc hash(v: Vec2): Hash =
  hash((v.x, v.y))

proc hash(radii: array[DirectionCorners, float32]): Hash =
  for r in radii:
    result = result !& hash(r)

proc clampRadii(radii: array[DirectionCorners, float32], rect: Rect): array[DirectionCorners, float32] =
  result = radii
  for r in result.mitems():
    r = max(1.0, min(r, min(rect.w / 2, rect.h / 2))).ceil()

proc drawRoundedRect*(
    bxy: Boxy,
    rect: Rect,
    color: Color,
    radii: array[DirectionCorners, float32],
    weight: float32 = -1.0,
    doStroke: bool = false,
) =
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

    if not bxy.hasImage($hashes[dcTopRight]):
      let circle =
        if doStroke:
          generateCircleBox(radii, stroked = true, lineWidth = weight)
        else:
          generateCircleBox(radii, stroked = false, lineWidth = weight)

      # circle.writeFile("examples/renderer-stroke-circle.png")
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
        bxy.addImage($hashes[quadrant], img)

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
        # uvRect = bxy.entries[hashes[corner]]
        # wh = rect.wh * bxy.atlasSize.float32
        pt = xy + offsets[corner]

      # bxy.drawUvRect(pt, pt + rw, uvRect.xy, uvRect.xy + uvRect.wh, color)
      bxy.drawImage($hashes[corner], pt, color)

  block drawEdgeBoxes:
    let
      ww = if doStroke: weight else: maxRadius
      rrw = if doStroke: w - weight else: w - rw
      rrh = if doStroke: h - weight else: h - rh
      wrw = w - 2 * rw
      hrh = h - 2 * rh

    if not doStroke:
      bxy.drawRect(rect(rect.x + rw, rect.y + rh, wrw, hrh), color)

    bxy.drawRect(rect(rect.x + rw, rect.y, wrw, ww), color)
    bxy.drawRect(rect(rect.x + rw, rect.y + rrh, wrw, ww), color)

    bxy.drawRect(rect(rect.x, rect.y + rh, ww, hrh), color)
    bxy.drawRect(rect(rect.x + rrw, rect.y + rh, ww, hrh), color)
