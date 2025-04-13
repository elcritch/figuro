import std/[strutils, paths, os]
# import ./apis

import stylus
import patty
import chroma
import chronicles

import cssgrid
import cssgrid/gridtypes
import cssgrid/variables
import basics

variantp CssValue:
  MissingCssValue
  CssColor(c: Color)
  CssSize(cx: Constraint)
  CssVarName(id: CssVarId)
  CssShadow(sstyle: ShadowStyle, sx, sy, sblur, sspread: Constraint, scolor: Color)
  CssAttribute(a: Atom)

type
  CssParserEofError* = object of CatchableError
  CssError* = object of CatchableError
  InvalidCssBody* = object of CssError

  CssParser* = ref object
    buff*: seq[Token]
    tokenizer*: Tokenizer

  CssBlock* = object
    selectors*: seq[CssSelector]
    properties*: seq[CssProperty]

  CssSelectorKind* {.pure.} = enum
    skNone
    skDirectChild
    skDescendent
    skPseudo
    skSelectorList

  CssSelector* = object
    cssType*: Atom
    class*: Atom
    id*: Atom
    combinator*: CssSelectorKind

  CssProperty* = object
    name*: Atom
    value*: CssValue

proc `$`*(val: CssValue): string =
  match val:
    MissingCssValue:
      "<empty>"
    CssColor(c):
      toHtmlHex(c)
    CssSize(cx):
      match cx:
        UiValue(value):
          $value
        _:
          $cx
    CssAttribute(n):
      $n
    CssVarName(n):
      "var(" & $n & ")"
    CssShadow(style, x, y, blur, spread, color):
      fmt"{x} {y} {blur} {spread} {color.toHtmlHex()} {style})"

proc `$`*(vals: openArray[CssValue]): string =
  for val in vals:
    result &= " "
    result.add $val

proc `$`*(selector: CssSelector): string =
  ## Convert a selector to its string representation
  result = ""
  if selector.id.len > 0:
    result.add "#" & $selector.id
  if selector.cssType.len > 0:
    if selector.combinator == skPseudo:
      result.add ":" & $selector.cssType
    else:
      result.add $selector.cssType
  if selector.class.len > 0:
    result.add "." & $selector.class
  
  case selector.combinator:
    of skDirectChild:
      result.add " > "
    of skDescendent:
      result.add " "
    of skSelectorList:
      result.add ", "
    else:
      discard

proc `$`*(selectors: openArray[CssSelector]): string =
  for selector in selectors:
    result.add $selector
    result.add " "

proc `$`*(selectors: seq[CssSelector]): string =
  for selector in selectors:
    result.add $selector
    result.add " "

proc `$`*(property: CssProperty): string =
  ## Convert a property to its string representation
  if property.name.len > 0:
    result = $property.name & ": " & $property.value & ";"

proc `$`*(cssBlock: CssBlock): string =
  ## Convert a CSS block to its string representation
  if cssBlock.selectors.len == 0:
    return ""
  
  # Format selectors
  for i, selector in cssBlock.selectors:
    if i > 0 and selector.combinator notin {skDirectChild, skPseudo, skDescendent}:
      result.add ", "
    result.add $selector
  
  result.add " {\n"
  
  # Format properties
  for property in cssBlock.properties:
    let propStr = $property
    if propStr.len > 0:
      result.add "  " & propStr & "\n"
  
  result.add "}"
