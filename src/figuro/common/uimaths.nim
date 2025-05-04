import std/[strutils, math, hashes]
import vmath, bumpy
import cssgrid/numberTypes

export math, vmath, numberTypes

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## Distinct percentages
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

type
  PercKind* = enum
    relative
    absolute

  Percent* = distinct float32
  Percentages* = tuple[value: float32, kind: PercKind]


converter toUis*[F: float | int | float32](x: static[F]): UiScalar =
  UiScalar x

proc `'ui`*(n: string): UiScalar {.compileTime.} =
  ## numeric literal UI Coordinate unit
  result = UiScalar(parseFloat(n))

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## Distinct vec types
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

type Box* = UiBox
type Position* = UiPos
type Size* = UiSize

# type Position* = distinct Vec2
proc initBox*(x, y, w, h: UiScalar | SomeNumber): Box =
  uiBox(x.UiScalar, y.UiScalar, w.UiScalar, h.UiScalar).Box

proc initPosition*(x, y: UiScalar): Position =
  uiPos(x, y).Position
proc initPosition*(x, y: float32): Position =
  initPosition(x.UiScalar, y.UiScalar)

proc initSize*(x, y: UiScalar): Size =
  uiPos(x, y).Size
proc initSize*(x, y: float32): Size =
  initSize(x.UiScalar, y.UiScalar)

proc hash*(p: Position): Hash =
  result = Hash(0)
  result = result !& hash(p.x)
  result = result !& hash(p.y)
  result = !$result

proc atXY*[T: Box](rect: T, x, y: int | float32): T =
  result = rect
  result.x = UiScalar(x)
  result.y = UiScalar(y)

proc atXY*[T: Box](rect: T, x, y: UiScalar): T =
  result = rect
  result.x = x
  result.y = y

proc atXY*[T: Rect](rect: T, x, y: int | float32): T =
  result = rect
  result.x = x
  result.y = y

proc `~=`*(rect: Vec2, val: float32): bool =
  result = rect.x ~= val and rect.y ~= val

# proc `$`*(a: Position): string {.borrow.}
# proc `$`*(a: Box): string {.borrow.}

proc overlaps*(a, b: Position): bool =
  overlaps(a.toVec(), b.toVec())

proc overlaps*(a: Position, b: Box): bool =
  overlaps(a.toVec(), b.toRect())

proc overlaps*(a: Box, b: Position): bool =
  overlaps(a.toRect(), b.toVec())

proc overlaps*(a: Box, b: Box): bool =
  overlaps(a.toRect(), b.toRect())

proc sum*(rect: Position): UiScalar =
  result = rect.x + rect.y

proc sum*(rect: Rect): float32 =
  result = rect.x + rect.y + rect.w + rect.h

proc sum*(rect: (float32, float32, float32, float32)): float32 =
  result = rect[0] + rect[1] + rect[2] + rect[3]

proc sum*(rect: Box): UiScalar =
  result = rect.x + rect.y + rect.w + rect.h

proc sum*(rect: (UiScalar, UiScalar, UiScalar, UiScalar)): UiScalar =
  result = rect[0] + rect[1] + rect[2] + rect[3]

proc clamp*(v: Position, a, b: Position): Position =
  initPosition(v.x.clamp(a.x, b.x).float32, v.y.clamp(a.y, b.y).float32)

proc clamp*(v: Size, a, b: Size): Size =
  uiSize(v.w.clamp(a.w, b.w).float32, v.h.clamp(a.h, b.h).float32)

proc clamp*(v: Position, a: UiScalar | Position, b: UiScalar | Position): Position =
  when typeof(a) isnot Position:
    let a = initPosition(a, a)
  when typeof(b) isnot Position:
    let b = initPosition(b, b)
  v.clamp(a, b)

proc clamp*(v: Size, a: UiScalar | Size, b: UiScalar | Size): Size =
  when typeof(a) isnot Size:
    let a = initSize(a, a)
  when typeof(b) isnot Size:
    let b = initSize(b, b)
  v.clamp(a, b)

# proc toJsonHook*(self: var Position; opt = initToJsonOptions()): JsonNode =
#   var x: float = self.x.float
#   var y: float = self.y.float
#   result = newJArray()
#   result.add x.toJson(opt)
#   result.add y.toJson(opt)

# proc fromJsonHook*(self: var Position; jn: JsonNode; opt = Joptions()) =
#   var val: array[2, float]
#   val[0] = jn[0].getFloat
#   val[1] = jn[1].getFloat
#   self = initPosition(val[0], val[1])

# when isMainModule:
# proc testPosition() =
#   let x = initPosition(12.1, 13.4)
#   let y = initPosition(10.0, 10.0)
#   var z = initPosition(0.0, 0.0)
#   let c = 1.0'ui

#   echo "x + y: ", repr(x + y)
#   echo "x - y: ", repr(x - y)
#   echo "x / y: ", repr(x / y)
#   echo "x / c: ", repr(x / c)
#   echo "x * y: ", repr(x * y)
#   echo "x == y: ", repr(x == y)
#   echo "x ~= y: ", repr(x ~= y)
#   echo "min(x, y): ", repr(min(x, y))

#   z = vec2(1.0, 1.0).Position
#   z += y
#   z += 3.1'f32
#   echo "z: ", repr(z)
#   z = vec2(1.0, 1.0).Position
#   echo "z: ", repr(-z)
#   echo "z: ", repr(sin(z))

# proc testRect() =
#   let x = initBox(10.0, 10.0, 2.0, 2.0).Box
#   let y = initBox(10.0, 10.0, 5.0, 5.0).Box
#   let c = 10.0'ui
#   var z = initBox(10.0, 10.0, 5.0, 5.0).Box
#   let v = initPosition(10.0, 10.0)

#   echo "x.w: ", repr(x.w)
#   echo "x + y: ", repr(x + y)
#   echo "x / y: ", repr(x / c)
#   echo "x * y: ", repr(x * c)
#   echo "x == y: ", repr(x == y)

#   z = rect(10.0, 10.0, 5.0, 5.0).Box
#   z.xy= v
#   # z += 3.1'f32
#   echo "z: ", repr(z)
#   z = rect(10.0, 10.0, 5.0, 5.0).Box

# when isMainModule:
#   testPosition()
#   testRect()
