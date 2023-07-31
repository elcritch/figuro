import strformat, strutils, hashes

import patty
export patty

import vmath, bumpy, math
export math, vmath, bumpy

import macros, macroutils
import typetraits

import typography/font
import cssgrid
import cdecl/atoms
import options

export options
export atoms

proc repr*(font: Font): string =
  if font.isNil:
    result = "Font(nil)"
  else:
    result = fmt"Font({font.typeface.name=}, {font.size=}, {font.weight=})"

macro variants*(name, code: untyped) =
  ## convenience wrapper for Patty variant macros
  result = quote do:
    {.push hint[Name]: off.}
    variantp `name`:
      ## test
    {.pop.}
  result[1][2] = code

template borrowMaths*(typ, base: typedesc) =
  proc `+` *(x, y: typ): typ = typ(`+`(base(x), base(y)))
  proc `-` *(x, y: typ): typ = typ(`-`(base(x), base(y)))
  
  proc `-` *(x: typ): typ = typ(`-`(base(x)))

  ## allow NewType(3.2) + 3.2 ... 
  proc `+` *(x: typ, y: static[float32|float64|int]): typ = typ(`+`(base x, base y))
  proc `-` *(x: typ, y: static[float32|float64|int]): typ = typ(`-`(base x, base y))
  proc `+` *(x: static[float32|float64|int], y: typ): typ = typ(`+`(base x, base y))
  proc `-` *(x: static[float32|float64|int], y: typ): typ = typ(`-`(base x, base y))

  proc `floor` *(x: typ): typ {.borrow.}
  proc `clamp` *(v: typ, a, b: typ): typ = typ(clamp(base(v), base(a), base(b)))
  proc `clamp` *(v, a: typ, b: static[float32|float64|int|typ]): typ = typ(clamp(base(v), base(a), base(b)))
  proc `clamp` *(v: typ, a, b: static[float32|float64|int|typ]): typ = typ(clamp(base(v), base(a), base(b)))

  proc `*` *(x, y: typ): typ = typ(`*`(base(x), base(y)))
  proc `/` *(x, y: typ): typ = typ(`/`(base(x), base(y)))

  proc `*` *(x: typ, y: static[distinctBase(typ)]): typ = typ(`*`(base(x), base(y)))
  proc `/` *(x: typ, y: static[distinctBase(typ)]): typ = typ(`/`(base(x), base(y)))
  proc `*` *(x: static[base], y: typ): typ = typ(`*`(base(x), base(y)))
  proc `/` *(x: static[base], y: typ): typ = typ(`/`(base(x), base(y)))

  proc `min` *(x: typ, y: typ): typ {.borrow.}
  proc `max` *(x: typ, y: typ): typ {.borrow.}

  proc `<` * (x, y: typ): bool {.borrow.}
  proc `<=` * (x, y: typ): bool {.borrow.}
  proc `==` * (x, y: typ): bool {.borrow.}

  proc `+=` * (x: var typ, y: typ) {.borrow.}
  proc `-=` * (x: var typ, y: typ) {.borrow.}
  proc `/=` * (x: var typ, y: typ) {.borrow.}
  proc `*=` * (x: var typ, y: typ) {.borrow.}
  proc `$` * (x: typ): string {.borrow.}
  proc `hash` * (x: typ): Hash {.borrow.}

template borrowMathsMixed*(typ: typedesc) =
  proc `*` *(x: typ, y: distinctBase(typ)): typ {.borrow.}
  proc `*` *(x: distinctBase(typ), y: typ): typ {.borrow.}
  proc `/` *(x: typ, y: distinctBase(typ)): typ {.borrow.}
  proc `/` *(x: distinctBase(typ), y: typ): typ {.borrow.}


template genBoolOp[T, B](op: untyped) =
  proc `op`*(a, b: T): bool = `op`(B(a), B(b))

template genFloatOp[T, B](op: untyped) =
  proc `op`*(a: T, b: UICoord): T = T(`op`(B(a), b.float32))

template genEqOp[T, B](op: untyped) =
  proc `op`*(a: var T, b: float32) = `op`(B(a), b)
  proc `op`*(a: var T, b: T) = `op`(B(a), B(b))

template genEqOpC[T, B, C](op: untyped) =
  proc `op`*[D](a: var T, b: D) = `op`(B(a), C(b))

template genMathFn[T, B](op: untyped) =
  proc `op`*(a: `T`): `T` =
    T(`op`(B(a)))

template genOp[T, B](op: untyped) =
  proc `op`*(a, b: T): T = T(`op`(B(a), B(b)))

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

borrowMaths(Percent, float32)
# borrowMathsMixed(Percent)

type
  # ScaledCoord* = distinct float32
  UICoord* = distinct float32

# borrowMaths(ScaledCoord)
borrowMaths(UICoord, float32)

converter toUI*[F: float|int|float32](x: static[F]): UICoord = UICoord x

proc `'ui`*(n: string): UICoord =
  ## numeric literal UI Coordinate unit
  result = UICoord(parseFloat(n))

template scaled*(a: UICoord): float32 =
  a.float32 * common.uiScale
template descaled*(a: float32): UICoord =
  UICoord(a / common.uiScale)

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ 
## Distinct vec types
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ 

type
  Position* = distinct Vec2

proc initPosition*(x, y: float32): Position = Position(vec2(x, y))
genBoolOp[Position, Vec2](`==`)
genBoolOp[Position, Vec2](`!=`)
genBoolOp[Position, Vec2](`~=`)

applyOps(Position, Vec2, genOp, `+`, `-`, `/`, `*`, `mod`, `zmod`, `min`, `zmod`)
applyOps(Position, Vec2, genEqOp, `+=`, `-=`, `*=`, `/=`)
applyOps(Position, Vec2, genMathFn, `-`, sin, cos, tan, arcsin, arccos, arctan, sinh, cosh, tanh)
applyOps(Position, Vec2, genMathFn, exp, ln, log2, sqrt, floor, ceil, abs) 
applyOps(Position, Vec2, genFloatOp, `*`, `/`)

type
  Box* = distinct Rect

proc initBox*(x, y, w, h: float32): Box = Box(rect(x, y, w, h))
proc initBox*(x, y, w, h: UICoord): Box = Box(rect(x.float32, y.float32, w.float32, h.float32))

applyOps(Box, Rect, genOp, `+`)
applyOps(Box, Rect, genFloatOp, `*`, `/`)
genBoolOp[Box, Rect](`==`)
genEqOpC[Box, Rect, Vec2](`xy=`)

template x*(r: Box): UICoord = r.Rect.x.UICoord
template y*(r: Box): UICoord = r.Rect.y.UICoord
template w*(r: Box): UICoord = r.Rect.w.UICoord
template h*(r: Box): UICoord = r.Rect.h.UICoord
template `x=`*(r: Box, v: UICoord) = r.Rect.x = v.float32
template `y=`*(r: Box, v: UICoord) = r.Rect.y = v.float32
template `w=`*(r: Box, v: UICoord) = r.Rect.w = v.float32
template `h=`*(r: Box, v: UICoord) = r.Rect.h = v.float32

template xy*(r: Box): Position = Position r.Rect.xy
template wh*(r: Box): Position = initPosition(r.w.float32, r.h.float32)

template x*(r: Position): UICoord = r.Vec2.x.UICoord
template y*(r: Position): UICoord = r.Vec2.y.UICoord
template `x=`*(r: Position, v: UICoord) = r.Vec2.x = v.float32
template `y=`*(r: Position, v: UICoord) = r.Vec2.y = v.float32

proc `+`*(rect: Box, xy: Position): Box =
  ## offset rect with xy vec2 
  result = rect
  result.x += xy.x
  result.y += xy.y

proc `-`*(rect: Box, xy: Position): Box =
  ## offset rect with xy vec2 
  result = rect
  result.x -= xy.x
  result.y -= xy.y

# proc `$`*(a: Position): string {.borrow.}
# proc `$`*(a: Box): string {.borrow.}

template scaled*(a: Box): Rect = Rect(a * common.uiScale.UICoord)
template descaled*(a: Rect): Box = Box(a / common.uiScale)

template scaled*(a: Position): Vec2 = Vec2(a * common.uiScale.UICoord)
template descaled*(a: Vec2): Position = Position(a / common.uiScale)

proc overlaps*(a, b: Position): bool = overlaps(Vec2(a), Vec2(b))
proc overlaps*(a: Position, b: Box): bool = overlaps(Vec2(a), Rect(b))
proc overlaps*(a: Box, b: Position): bool = overlaps(Rect(a), Vec2(b))
proc overlaps*(a: Box, b: Box): bool = overlaps(Rect(a), Rect(b))

proc sum*(rect: Rect): float32 =
  result = rect.x + rect.y + rect.w + rect.h
proc sum*(rect: (float32, float32, float32, float32)): float32 =
  result = rect[0] + rect[1] + rect[2] + rect[3]
proc sum*(rect: Box): UICoord =
  result = rect.x + rect.y + rect.w + rect.h
proc sum*(rect: (UICoord, UICoord, UICoord, UICoord)): UICoord =
  result = rect[0] + rect[1] + rect[2] + rect[3]

proc `$`*(a: Position): string =
  &"Position<{a.x:2.2f}, {a.y:2.2f}>"
proc `$`*(b: Box): string =
  let a = b.Rect
  &"Box<{a.x:2.2f}, {a.y:2.2f}; {a.x+a.w:2.2f}, {a.y+a.h:2.2f} [{a.w:2.2f} x {a.h:2.2f}]>"


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
