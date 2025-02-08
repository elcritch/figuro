import std/[strformat, strutils, math, hashes, macros, typetraits]
import macroutils, vmath, bumpy
import cssgrid/numberTypes

export math, vmath, numberTypes

template borrowMaths*(typ, base: typedesc) =
  proc `+`*(x, y: typ): typ =
    typ(`+`(base(x), base(y)))

  proc `-`*(x, y: typ): typ =
    typ(`-`(base(x), base(y)))

  proc `-`*(x: typ): typ =
    typ(`-`(base(x)))

  ## allow NewType(3.2) + 3.2 ... 
  proc `+`*(x: typ, y: static[float32 | float64 | int]): typ =
    typ(`+`(base x, base y))

  proc `-`*(x: typ, y: static[float32 | float64 | int]): typ =
    typ(`-`(base x, base y))

  proc `+`*(x: static[float32 | float64 | int], y: typ): typ =
    typ(`+`(base x, base y))

  proc `-`*(x: static[float32 | float64 | int], y: typ): typ =
    typ(`-`(base x, base y))

  proc `floor`*(x: typ): typ {.borrow.}
  proc `clamp`*(v: typ, a, b: typ): typ =
    typ(clamp(base(v), base(a), base(b)))

  proc `clamp`*(v, a: typ, b: static[float32 | float64 | int | typ]): typ =
    typ(clamp(base(v), base(a), base(b)))

  proc `clamp`*(v: typ, a, b: static[float32 | float64 | int | typ]): typ =
    typ(clamp(base(v), base(a), base(b)))

  proc `*`*(x, y: typ): typ =
    typ(`*`(base(x), base(y)))

  proc `/`*(x, y: typ): typ =
    typ(`/`(base(x), base(y)))

  proc `*`*(x: typ, y: static[distinctBase(typ)]): typ =
    typ(`*`(base(x), base(y)))

  proc `/`*(x: typ, y: static[distinctBase(typ)]): typ =
    typ(`/`(base(x), base(y)))

  proc `*`*(x: static[base], y: typ): typ =
    typ(`*`(base(x), base(y)))

  proc `/`*(x: static[base], y: typ): typ =
    typ(`/`(base(x), base(y)))

  proc `min`*(x: typ, y: typ): typ {.borrow.}
  proc `max`*(x: typ, y: typ): typ {.borrow.}

  proc `<`*(x, y: typ): bool {.borrow.}
  proc `<=`*(x, y: typ): bool {.borrow.}
  proc `==`*(x, y: typ): bool {.borrow.}

  proc `+=`*(x: var typ, y: typ) {.borrow.}
  proc `-=`*(x: var typ, y: typ) {.borrow.}
  proc `/=`*(x: var typ, y: typ) {.borrow.}
  proc `*=`*(x: var typ, y: typ) {.borrow.}
  proc `$`*(x: typ): string {.borrow.}
  # proc `hash`*(x: typ): Hash {.borrow.}

template borrowMathsMixed*(typ: typedesc) =
  proc `*`*(x: typ, y: distinctBase(typ)): typ {.borrow.}
  proc `*`*(x: distinctBase(typ), y: typ): typ {.borrow.}
  proc `/`*(x: typ, y: distinctBase(typ)): typ {.borrow.}
  proc `/`*(x: distinctBase(typ), y: typ): typ {.borrow.}

template genBoolOp[T, B](op: untyped) =
  proc `op`*(a, b: T): bool =
    `op`(B(a), B(b))

template genFloatOp[T, B](op: untyped) =
  proc `op`*(a: T, b: UiScalar): T =
    T(`op`(B(a), b.float32))

template genEqOp[T, B](op: untyped) =
  proc `op`*(a: var T, b: float32) =
    `op`(B(a), b)

  proc `op`*(a: var T, b: T) =
    `op`(B(a), B(b))

template genEqOpC[T, B, C](op: untyped) =
  proc `op`*[D](a: var T, b: D) =
    `op`(B(a), C(b))

template genMathFn[T, B](op: untyped) =
  proc `op`*(a: `T`): `T` =
    T(`op`(B(a)))

template genOp[T, B](op: untyped) =
  proc `op`*(a, b: T): T =
    T(`op`(B(a), B(b)))

macro applyOps(a, b: typed, fn: untyped, ops: varargs[untyped]) =
  result = newStmtList()
  for op in ops:
    result.add quote do:
      `fn`[`a`, `b`](`op`)

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

# type Position* = distinct Vec2

proc initPosition*(x, y: UiScalar): Position =
  uiPos(x, y).Position

proc initPosition*(x, y: float32): Position =
  initPosition(x.UiScalar, y.UiScalar)

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

proc clamp*[U, V](v: Position, a: U, b: V): Position =
  when U isnot Position:
    let a = initPosition(a, a)
  when V isnot Position:
    let b = initPosition(b, b)
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
