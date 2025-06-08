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
