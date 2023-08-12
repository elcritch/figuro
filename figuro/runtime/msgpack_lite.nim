# MessagePack implementation written in nim
#
# Copyright (c) 2015-2019 Andri Lim
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
#-------------------------------------
import macros
import tables


template swapEndian64*(outp, inp: uint64|int64) =
  outp = 0
  for i in 0..<sizeof(inp):
    outp = (outp shl 8) or (0xFF and (inp shr (i*8)))

template swapEndian32*(outp, inp: int32|uint32) =
  outp = 0
  for i in 0..<sizeof(inp):
    outp = (outp shl 8) or (0xFF and (inp shr (i*8)))

template swapEndian16*(outp, inp: int16|uint16) =
  outp = 0
  for i in 0..<sizeof(inp):
    outp = (outp shl 8) or (0xFF and (inp shr (i*8)))

when isMainModule:
  var a, b: int32
  b = 0xFFFFAAAA'i32
  swapEndian32(a, b)
  echo "b: ", b
  echo "a: ", a
  echo "a[3]: ", (a shr (3*8)) and 0xFF
  echo "a[2]: ", (a shr (2*8)) and 0xFF
  echo "a[1]: ", (a shr (1*8)) and 0xFF
  echo "a[0]: ", (a shr (0*8)) and 0xFF

when not declared SomeFloat:
  type
    SomeFloat = SomeReal

const pack_value_nil* = chr(0xc0)

type
  StringStream = ref object
    data*: string

type
  EncodingMode* = enum
    MSGPACK_OBJ_TO_DEFAULT
    MSGPACK_OBJ_TO_ARRAY
    MSGPACK_OBJ_TO_MAP
    MSGPACK_OBJ_TO_STREAM


var encodingMode* = MSGPACK_OBJ_TO_MAP


proc write*(s: StringStream, val: char|uint8|int8) =
  s.data.add(cast[char](val))

proc write*(s: StringStream, val: uint16|int16|uint32|int32|uint64|int64) =
  for i in 0..<sizeof(val):
    let c = cast[char](0xFF and (val shr (i*8)))
    s.data.add(c)

proc write*(s: StringStream, val: string) =
  if val.len > 0:
    # writeData(s, unsafeAddr val[0], val.len)
    for c in val: s.data.add(c)


proc conversionError*(msg: string): ref ObjectConversionError =
  new(result)
  result.msg = msg

template skipUndistinct* {.pragma, deprecated.}
  # no need to use this pragma anymore
  # the undistinct macro is more clever now

proc getParamIdent(n: NimNode): NimNode =
  n.expectKind({nnkIdent, nnkVarTy, nnkSym})
  if n.kind in {nnkIdent, nnkSym}:
    result = n
  else:
    result = n[0]

proc hasDistinctImpl(w: NimNode, z: NimNode): bool =
  for k in w:
    let p = k.getImpl()[3][2][1]
    if p.kind in {nnkIdent, nnkVarTy, nnkSym}:
      let paramIdent = getParamIdent(p)
      if eqIdent(paramIdent, z): return true

proc needToSkip(typ: NimNode | typedesc, w: NimNode): bool {.compileTime.} =
  let z = getType(typ)[1]

  if z.kind == nnkSym:
    if hasDistinctImpl(w, z): return true

  if z.kind != nnkSym: return false
  let impl = getImpl(z)
  if impl.kind != nnkTypeDef: return false
  if impl[2].kind != nnkDistinctTy: return false
  if impl[0].kind != nnkPragmaExpr: return false
  let prag = impl[0][1][0]
  result = eqIdent("skipUndistinct", prag)

#this macro convert any distinct types to it's base type
macro undistinctImpl*(x: typed, typ: typedesc, w: typed): untyped =
  var ty = getType(x)
  if needToSkip(typ, w):
    result = x
    return
  var isDistinct = ty.typekind == ntyDistinct
  if isDistinct:
    let parent = ty[1]
    result = quote do: `parent`(`x`)
  else:
    result = x

template undistinct_pack*(x: typed): untyped =
  undistinctImpl(x, type(x), bindSym("pack_type", brForceOpen))

template undistinct_unpack*(x: typed): untyped =
  undistinctImpl(x, type(x), bindSym("unpack_type", brForceOpen))

when system.cpuEndian == littleEndian:
  proc take8_8(val: uint8): uint8 {.inline.} = val
  proc take8_16(val: uint16): uint8 {.inline.} = uint8(val and 0xFF)
  proc take8_32(val: uint32): uint8 {.inline.} = uint8(val and 0xFF)
  proc take8_64(val: uint64): uint8 {.inline.} = uint8(val and 0xFF)

  proc store16[StringStream](s: StringStream, val: uint16) =
    var res: uint16
    swapEndian16(res, val)
    s.write(res)
  proc store32[StringStream](s: StringStream, val: uint32) =
    var res: uint32
    swapEndian32(res, val)
    s.write(res)
  proc store64[StringStream](s: StringStream, val: uint64) =
    var res: uint64
    swapEndian64(res, val)
    s.write(res)
else:
  proc take8_8(val: uint8): uint8 {.inline.} = val
  proc take8_16(val: uint16): uint8 {.inline.} = (val shr 8) and 0xFF
  proc take8_32(val: uint32): uint8 {.inline.} = (val shr 24) and 0xFF
  proc take8_64(val: uint64): uint8 {.inline.} = uint8((val shr 56) and 0xFF)

  proc store16[StringStream](s: StringStream, val: uint16) = s.write(val)
  proc store32[StringStream](s: StringStream, val: uint32) = s.write(val)
  proc store64[StringStream](s: StringStream, val: uint64) = s.write(val)
  proc unstore16[StringStream](s: StringStream): uint16 = cast[uint16](s.readInt16)
  proc unstore32[StringStream](s: StringStream): uint32 = cast[uint32](s.readInt32)
  proc unstore64[StringStream](s: StringStream): uint64 = cast[uint64](s.readInt64)

proc take8_8[T:uint8|char|int8](val: T): uint8 {.inline.} = uint8(val)
proc take16_8[T:uint8|char|int8](val: T): uint16 {.inline.} = uint16(val)
proc take32_8[T:uint8|char|int8](val: T): uint32 {.inline.} = uint32(val)
proc take64_8[T:uint8|char|int8](val: T): uint64 {.inline.} = uint64(val)

proc pack_bool*(s: StringStream, val: bool) =
  if val: s.write(chr(0xc3))
  else: s.write(chr(0xc2))

proc pack_imp_nil*(s: StringStream) =
  s.write(chr(0xc0))

proc pack_imp_uint8*(s: StringStream, val: uint8) =
  if val < uint8(1 shl 7):
    #fixnum
    s.write(take8_8(val))
  else:
    #unsigned 8
    s.write(chr(0xcc))
    s.write(take8_8(val))

proc pack_imp_uint16*(s: StringStream, val: uint16) =
  if val < uint16(1 shl 7):
    #fixnum
    s.write(take8_16(val))
  elif val < uint16(1 shl 8):
    #unsigned 8
    s.write(chr(0xcc))
    s.write(take8_16(val))
  else:
    #unsigned 16
    s.write(chr(0xcd))
    s.store16(val)

proc pack_imp_uint32*(s: StringStream, val: uint32) =
  if val < uint32(1 shl 8):
    if val < uint32(1 shl 7):
      #fixnum
      s.write(take8_32(val))
    else:
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_32(val))
  else:
    if val < uint32(1 shl 16):
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))
    else:
      #unsigned 32
      s.write(chr(0xce))
      s.store32(val)


proc pack_imp_uint64*(s: StringStream, val: uint64) =
  if val < uint64(1 shl 8):
    if val < uint64(1 shl 7):
      #fixnum
      s.write(take8_64(val))
    else:
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_64(val))
  else:
    if val < uint64(1 shl 16):
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))
    elif val < uint64(1 shl 32):
      #unsigned 32
      s.write(chr(0xce))
      s.store32(uint32(val))
    else:
      #unsigned 64
      s.write(chr(0xcf))
      s.store64(val)


proc pack_imp_int8*(s: StringStream, val: int8) =
  if val < -(1 shl 5):
    #signed 8
    s.write(chr(0xd0))
    s.write(take8_8(cast[uint8](val)))
  else:
    #fixnum
    s.write(take8_8(cast[uint8](val)))


proc pack_imp_int16*(s: StringStream, val: int16) =
  if val < -(1 shl 5):
    if val < -(1 shl 7):
      #signed 16
      s.write(chr(0xd1))
      s.store16(cast[uint16](val))
    else:
      #signed 8
      s.write(chr(0xd0))
      var x = cast[char](take8_16(cast[uint16](val)))
      s.write(x)
  elif val < (1 shl 7):
    var x = cast[char](take8_16(cast[uint16](val)))
    #fixnum
    s.write(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_16(uint16(val)))
    else:
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))


proc pack_imp_int32*(s: StringStream, val: int32) =
  if val < -(1 shl 5):
    if val < -(1 shl 15):
      #signed 32
      s.write(chr(0xd2))
      s.store32(cast[uint32](val))
    elif val < -(1 shl 7):
      #signed 16
      s.write(chr(0xd1))
      s.store16(cast[uint16](val))
    else:
      #signed 8
      s.write(chr(0xd0))
      var x = cast[char](take8_32(cast[uint32](val)))
      s.write(x)
  elif val < (1 shl 7):
    #fixnum
    var x = cast[char](take8_32(cast[uint32](val)))
    s.write(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_32(uint32(val)))
    elif val < (1 shl 16):
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))
    else:
      #unsigned 32
      s.write(chr(0xce))
      s.store32(uint32(val))


proc pack_imp_int64*(s: StringStream, val: int64) =
  if val < -(1 shl 5):
    if val < -(1 shl 31):
      #signed 64
      s.write(chr(0xd3))
      s.store64(uint64(val))
    elif val < -(1 shl 15):
      #signed 32
      s.write(chr(0xd2))
      s.store32(cast[uint32](val))
    elif val < -(1 shl 7):
      #signed 16
      s.write(chr(0xd1))
      s.store16(cast[uint16](val))
    else:
      #signed 8
      s.write(chr(0xd0))
      var x = cast[char](take8_64(cast[uint64](val)))
      s.write(x)
  elif val < (1 shl 7):
    #fixnum
    var x = cast[char](take8_64(cast[uint64](val)))
    s.write(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_64(uint64(val)))
    elif val < (1 shl 16):
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))
    elif val < (1 shl 32):
      #unsigned 32
      s.write(chr(0xce))
      s.store32(uint32(val))
    else:
      #unsigned 64
      s.write(chr(0xcf))
      s.store64(uint64(val))


proc pack_imp_int*(s: StringStream, val: int) =
  case sizeof(val)
  of 1: s.pack_imp_int8(int8(val))
  of 2: s.pack_imp_int16(int16(val))
  of 4: s.pack_imp_int32(int32(val))
  else: s.pack_imp_int64(int64(val))

proc pack_array*(s: StringStream, len: int) =
  if len <= 0x0F:
    s.write(chr(0b10010000 or (len and 0x0F)))
  elif len > 0x0F and len <= 0xFFFF:
    s.write(chr(0xdc))
    s.store16(uint16(len))
  elif len > 0xFFFF:
    s.write(chr(0xdd))
    s.store32(uint32(len))

proc pack_map*(s: StringStream, len: int) =
  if len <= 0x0F:
    s.write(chr(0b10000000 or (len and 0x0F)))
  elif len > 0x0F and len <= 0xFFFF:
    s.write(chr(0xde))
    s.store16(uint16(len))
  elif len > 0xFFFF:
    s.write(chr(0xdf))
    s.store32(uint32(len))

proc pack_bin*(s: StringStream, len: int) =
  if len <= 0xFF:
    s.write(chr(0xc4))
    s.write(uint8(len))
  elif len > 0xFF and len <= 0xFFFF:
    s.write(chr(0xc5))
    s.store16(uint16(len))
  elif len > 0xFFFF:
    s.write(chr(0xc6))
    s.store32(uint32(len))

proc pack_ext*(s: StringStream, len: int, exttype: int8) =
  case len
  of 1:
    s.write(chr(0xd4))
    s.write(exttype)
  of 2:
    s.write(chr(0xd5))
    s.write(exttype)
  of 4:
    s.write(chr(0xd6))
    s.write(exttype)
  of 8:
    s.write(chr(0xd7))
    s.write(exttype)
  of 16:
    s.write(chr(0xd8))
    s.write(exttype)
  else:
    if len < 256:
      s.write(chr(0xc7))
      s.write(uint8(len))
      s.write(exttype)
    elif len < 65536:
      s.write(chr(0xc8))
      s.store16(uint16(len))
      s.write(exttype)
    else:
      s.write(chr(0xc9))
      s.store32(uint32(len))
      s.write(exttype)

proc pack_string*(s: StringStream, len: int) =
  # echo "pack string"
  if len < 32:
    var d = uint8(0xa0) or uint8(len)
    s.write(take8_8(d))
  elif len < 256:
    s.write(chr(0xd9))
    s.write(uint8(len))
  elif len < 65536:
    s.write(chr(0xda))
    s.store16(uint16(len))
  else:
    s.write(chr(0xdb))
    s.store32(uint32(len))

proc pack_type*(s: StringStream, val: bool) =
  s.pack_bool(val)

proc pack_type*(s: StringStream, val: char) =
  s.pack_imp_uint8(uint8(val))

proc pack_type*(s: StringStream, val: string) =
  when compiles(isNil(val)):
    if isNil(val): s.pack_imp_nil()
    else:
      s.pack_string(val.len)
      s.write(val)
  else:
    s.pack_string(val.len)
    s.write(val)

proc pack_type*(s: StringStream, val: uint8) =
  s.pack_imp_uint8(val)

proc pack_type*(s: StringStream, val: uint16) =
  s.pack_imp_uint16(val)

proc pack_type*(s: StringStream, val: uint32) =
  s.pack_imp_uint32(val)

proc pack_type*(s: StringStream, val: uint64) =
  s.pack_imp_uint64(val)

proc pack_type*(s: StringStream, val: int8) =
  s.pack_imp_int8(val)

proc pack_type*(s: StringStream, val: int16) =
  s.pack_imp_int16(val)

proc pack_type*(s: StringStream, val: int32) =
  s.pack_imp_int32(val)

proc pack_type*(s: StringStream, val: int64) =
  s.pack_imp_int64(val)

proc pack_int_imp_select[StringStream, T](s: StringStream, val: T) =
  when sizeof(val) == 1:
    s.pack_imp_int8(int8(val))
  elif sizeof(val) == 2:
    s.pack_imp_int16(int16(val))
  elif sizeof(val) == 4:
    s.pack_imp_int32(int32(val))
  else:
    s.pack_imp_int64(int64(val))

proc pack_uint_imp_select[StringStream, T](s: StringStream, val: T) =
  if sizeof(T) == 1:
    s.pack_imp_uint8(cast[uint8](val))
  elif sizeof(T) == 2:
    s.pack_imp_uint16(cast[uint16](val))
  elif sizeof(T) == 4:
    s.pack_imp_uint32(cast[uint32](val))
  else:
    s.pack_imp_uint64(cast[uint64](val))

proc pack_type*(s: StringStream, val: int) =
  pack_int_imp_select(s, val)

proc pack_type*(s: StringStream, val: uint) =
  pack_uint_imp_select(s, val)

proc pack_imp_float32[StringStream](s: StringStream, val: float32) {.inline.} =
  let tmp = cast[uint32](val)
  s.write(chr(0xca))
  s.store32(tmp)

proc pack_imp_float64[StringStream](s: StringStream, val: float64) {.inline.} =
  let tmp = cast[uint64](val)
  s.write(chr(0xcb))
  s.store64(tmp)

proc pack_type*(s: StringStream, val: float32) =
  s.pack_imp_float32(val)

proc pack_type*(s: StringStream, val: float64) =
  s.pack_imp_float64(val)

proc pack_type*(s: StringStream, val: SomeFloat) =
  when sizeof(val) == sizeof(float32):
    s.pack_imp_float32(float32(val))
  elif sizeof(val) == sizeof(float64):
    s.pack_imp_float64(float64(val))
  else:
    raise conversionError("float")

proc pack_type*[StringStream, T](s: StringStream, val: set[T]) =
  s.pack_array(card(val))
  for e in items(val):
    s.pack_imp_uint64(uint64(e))

proc pack_items_imp*[StringStream, T](s: StringStream, val: T) {.inline.} =
  var ss = StringStream.init(sizeof(T))
  var count = 0
  for i in items(val):
    ss.pack undistinct_pack(i)
    inc(count)
  s.pack_array(count)
  s.write(ss.data)

proc pack_map_imp*[StringStream, T](s: StringStream, val: T) {.inline.} =
  s.pack_map(val.len)
  for k,v in pairs(val):
    s.pack_type undistinct_pack(k)
    s.pack_type undistinct_pack(v)

proc pack_type*[StringStream, T](s: StringStream, val: openArray[T]) =
  s.pack_array(val.len)
  for i in 0..val.len-1: s.pack_type undistinct_pack(val[i])

proc pack_type*[StringStream, T](s: StringStream, val: seq[T]) =
  when compiles(isNil(val)):
    if isNil(val): s.pack_imp_nil()
    else:
      s.pack_array(val.len)
      for i in 0..val.len-1: s.pack_type undistinct_pack(val[i])
  else:
    s.pack_array(val.len)
    for i in 0..val.len-1: s.pack_type undistinct_pack(val[i])

proc pack_type*[StringStream; T: enum|range](s: StringStream, val: T) =
  when val is range:
    pack_int_imp_select(s, val.int64)
  else:
    pack_int_imp_select(s, val)

proc pack_type*[StringStream; T: tuple|object](s: StringStream, val: T) =
  var len = 0
  for field in fields(val):
    inc(len)

  template dry_and_wet() =
    when defined(msgpack_obj_to_map):
      s.pack_map(len)
      for field, value in fieldPairs(val):
        s.pack_type field
        s.pack_type undistinct_pack(value)
    elif defined(msgpack_obj_to_stream):
      for field in fields(val):
        s.pack_type undistinct_pack(field)
    else:
      s.pack_array(len)
      for field in fields(val):
        s.pack_type undistinct_pack(field)

  when StringStream is StringStream:
    case encodingMode
    of MSGPACK_OBJ_TO_ARRAY:
      s.pack_array(len)
      for field in fields(val):
        s.pack_type undistinct_pack(field)
    of MSGPACK_OBJ_TO_MAP:
      s.pack_map(len)
      for field, value in fieldPairs(val):
        s.pack_type field
        s.pack_type undistinct_pack(value)
    of MSGPACK_OBJ_TO_STREAM:
      for field in fields(val):
        s.pack_type undistinct_pack(field)
    else:
      dry_and_wet()
  else:
    dry_and_wet()

proc pack_type*[StringStream; T: ref](s: StringStream, val: T) =
  if isNil(val): s.pack_imp_nil()
  else: s.pack_type(val[])

proc pack_type*[StringStream, T](s: StringStream, val: ptr T) =
  if isNil(val): s.pack_imp_nil()
  else: s.pack_type(val[])



var mems = newSeq[string]()




proc pack_type*[StringStream; T: proc](s: StringStream, val: T) =
  s.pack_imp_nil()


proc pack_type*(s: StringStream, val: cstring) =
  s.pack_imp_nil()


proc pack_type*(s: StringStream, val: pointer) =
  s.pack_imp_nil()


proc pack*[StringStream, T](s: StringStream, val: T) =
  s.pack_type val

proc pack*[T](val: T): string =
  var s = StringStream(data: newString(0))
  s.pack(val)
  result = s.data

proc unpack*[T](data: string, val: var T) =
  var s = StringStream.init(data)
  s.setPosition(0)
  s.unpack(val)

proc unpack*[StringStream, T](s: StringStream, val: typedesc[T]): T {.inline.} =
  unpack(s, result)

proc unpack*[T](data: string, val: typedesc[T]): T {.inline.} =
  unpack(data, result)
