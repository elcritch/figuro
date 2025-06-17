import std/hashes

import ../../commons
import ../../common/nodes/render

import pkg/chroma
import pkg/sigils
import pkg/chronicles


proc hash(v: Vec2): Hash =
  hash((v.x, v.y))

proc hash(radii: array[DirectionCorners, float32]): Hash =
  for r in radii:
    result = result !& hash(r)

proc clampRadii*(radii: array[DirectionCorners, float32], rect: Rect): array[DirectionCorners, float32] =
  let maxRadius = min(rect.w / 2, rect.h / 2)
  result = radii
  for corner in DirectionCorners:
    result[corner] = max(1.0, min(radii[corner], maxRadius)).round()

proc cornersToSdfRadii*(radii: array[DirectionCorners, float32]): Vec4 =
  vec4(radii[dcBottomRight], radii[dcTopRight], radii[dcBottomLeft], radii[dcTopLeft])

proc getCircleBoxSizes*(
    radii: array[DirectionCorners, float32],
    blur: float32,
    spread: float32,
    weight: float32 = 0.0,
    width = float32.high(),
    height = float32.high(),
    innerShadow = false,
): tuple[maxRadius, sideSize, totalSize, padding, inner: int] =
  result.maxRadius = 0
  for r in radii:
    result.maxRadius = max(result.maxRadius, r.round().int)
  let ww = int(1.5*weight.round())
  let bw = width.round().int
  let bh = height.round().int
  let blur = blur.round().int
  let spread = spread.round().int
  let padding = max(spread + blur, result.maxRadius)

  result.padding = padding
  if innerShadow:
    result.sideSize = min(result.maxRadius + padding, min(bw, bh)).max(ww)
  else:
    result.sideSize = min(result.maxRadius, min(bw, bh)).max(ww)
  result.totalSize = 3*result.sidesize + 3*padding
  result.inner = 3*result.sideSize

proc roundedBoxCornerSizes*(
    radii: array[DirectionCorners, float32],
    blur: float32,
    spread: float32,
    weight: float32 = 0.0,
    width = float32.high(),
    height = float32.high(),
    innerShadow = false,
): array[DirectionCorners, tuple[corner, side, padding, sideSize, inner, totalSize: int]] =
  let ww = int(1.5*weight.round())
  let bw = width.round().int
  let bh = height.round().int
  var maxRadius = 0
  for r in radii:
    maxRadius = max(maxRadius, r.round().int)

  let padding = spread + 1.5 * blur
  let sideSize =
    if innerShadow:
      min(maxRadius + padding, min(bw, bh)).max(ww)
    else:
      min(maxRadius, min(bw, bh)).max(ww)
  let totalSize = 3*sideSize + 3*padding
  let inner = 3*sideSize

  for corner in DirectionCorners:
    result[corner] = (corner, sideSize, padding, sideSize, inner, totalSize)
