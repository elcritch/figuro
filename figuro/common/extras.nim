import std/[strformat, macros]
# import typography/font
import patty

export patty

iterator reverse*[T](a: openArray[T]): T {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield a[i]
    dec i

iterator reversePairs*[T](a: openArray[T]): (int, T) {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield (a.len - 1 - i, a[i])
    dec i

iterator reverseIndex*[T](a: openArray[T]): (int, T) {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield (i, a[i])
    dec i

# proc repr*(font: Font): string =
#   if font.isNil:
#     result = "Font(nil)"
#   else:
#     result = fmt"Font({font.typeface.name=}, {font.size=}, {font.weight=})"

macro variants*(name, code: untyped) =
  ## convenience wrapper for Patty variant macros
  result = quote do:
    {.push hint[Name]: off.}
    variantp `name`:
      ## test
    {.pop.}
  result[1][2] = code
