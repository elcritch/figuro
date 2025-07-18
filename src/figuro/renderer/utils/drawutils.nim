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
): tuple[maxRadius, sideSize, totalSize, padding, paddingOffset, inner, weightSize: int] =
  result.maxRadius = 0
  for r in radii:
    result.maxRadius = max(result.maxRadius, r.round().int)
  let ww = int(weight.round())
  let bw = width.round().int
  let bh = height.round().int
  let blur = round(1.5*blur).int
  let spread = spread.round().int
  # let padding = max(spread + blur, result.maxRadius)
  let padding = spread + blur

  result.padding = padding
  result.paddingOffset = result.padding
  if innerShadow:
    result.sideSize = min(result.maxRadius + padding, min(bw, bh)).max(ww)
  else:
    result.sideSize = min(result.maxRadius, min(bw, bh)).max(ww)
  result.totalSize = 3*result.sidesize + 3*padding
  result.inner = 3*result.sideSize
  result.weightSize = ww

proc roundedBoxCornerSizes*(
    cbs: tuple[maxRadius, sideSize, totalSize, padding, paddingOffset, inner, weightSize: int],
    radii: array[DirectionCorners, float32],
    innerShadow: bool,
): array[DirectionCorners, tuple[radius, sideSize, inner, sideDelta, center: int]] =
  let ww = cbs.weightSize

  for corner in DirectionCorners:
    let dim =
      if innerShadow: max(cbs.maxRadius, cbs.paddingOffset)
      else: max(int(round(radii[corner])), ww)
    let sideSize = cbs.paddingOffset + dim
    let center = sideSize
    result[corner] = (radius: int(round(radii[corner])),
                      sideSize: sideSize,
                      inner: dim,
                      sideDelta: cbs.sideSize - dim,
                      center: center)
