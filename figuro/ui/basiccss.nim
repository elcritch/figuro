import std/[paths, os]
# import ./apis

import cssgrid
import stylus
import patty
import chroma

variantp CssValue:
  MissingCssValue
  CssColor(c: Color)
  CssSize(cx: Constraint)
  CssVarName(n: string)

type
  CssParser* = ref object
    buff: seq[Token]
    tokenizer: Tokenizer

  CssBlock* = ref object
    selectors*: seq[CssSelector]
    properties*: seq[CssProperty]
  
  CssSelectorKind* {.pure.} = enum
    skNone,
    skDirectChild,
    skDescendent,
    skPseudo,
    skSelectorList

  CssSelector* = ref object
    cssType*: string
    class*: string
    id*: string
    combinator*: CssSelectorKind

  CssProperty* = ref object
    name*: string
    value*: CssValue

proc `==`*(a, b: CssSelector): bool =
  if a.isNil and b.isNil:
    return true
  if a.isNil or b.isNil:
    return false
  a[] == b[]
proc `==`*(a, b: CssProperty): bool =
  if a.isNil and b.isNil:
    return true
  if a.isNil or b.isNil:
    return false
  a[] == b[]

proc newCssParser*(src: string): CssParser =
  let tokenizer = newTokenizer(src)
  result = CssParser(tokenizer: tokenizer)

proc newCssParser*(file: Path): CssParser =
  let 
    data = readFile(file.string)
  result = newCssParser(data)

proc isEof(parser: CssParser): bool =
  parser.tokenizer.isEof()

proc peek(parser: CssParser): Token =
  if parser.isEof():
    raise newException(ValueError, "EOF!")
  if parser.buff.len() == 0:
    parser.buff.add(parser.tokenizer.nextToken())
  parser.buff[0]

proc nextToken(parser: CssParser): Token =
  if parser.isEof():
    raise newException(ValueError, "EOF!")
  if parser.buff.len() == 0:
    parser.tokenizer.nextToken()
  else:
    let tk = parser.buff[0]
    parser.buff.del(0)
    tk

proc eat(parser: CssParser, kind: TokenKind) =
  if parser.isEof():
    raise newException(ValueError, "EOF!")
  let tk = parser.nextToken()
  if tk.kind != kind:
    raise newException(ValueError, "Expected: " & $kind & " got: " & $tk.kind)

proc skip(parser: CssParser, kind: TokenKind = tkWhiteSpace) =
  while not parser.isEof():
    let tk = parser.peek()
    if parser.isEof():
      break
    if tk.kind == kind:
      # echo "\tskip whitespace"
      discard parser.nextToken()
      continue
    else:
      break

proc parseSelector(parser: CssParser): seq[CssSelector] =
  var
    isClass = false
    isPseudo = false
    isDirect = false

  while true:
    parser.skip(tkWhiteSpace)
    var tk = parser.peek()
    case tk.kind:
    of tkIdent:
      # echo "\tsel: ", tk.repr
      if isClass:
        if result.len() == 0:
          result.add(CssSelector())
        let tk = parser.nextToken()
        result[^1].class = tk.ident
        isClass = false
      else:
        let tk = parser.nextToken()
        result.add(CssSelector(cssType: tk.ident))
        if result.len() >= 2:
          result[^1].combinator = skDescendent
        if isDirect:
          # echo "\tsel:direct: ", result[^1].repr
          result[^1].combinator = skDirectChild
          isDirect = false
        elif isPseudo:
          result[^1].combinator = skPseudo
          isPseudo = false
    of tkColon:
      isPseudo = true
      discard parser.nextToken()
    of tkIDHash:
      result.add(CssSelector(id: tk.idHash))
      let tk = parser.nextToken()
    of tkDelim:
      case tk.delim:
      of '.':
        isClass = true
      of '<':
        isDirect = true
      else:
        echo "warning: ", "unhandled token while parsing selector: ", tk.repr()
      discard parser.nextToken()
    of tkCurlyBracketBlock:
      # echo "\tsel: ", "done"
      break
    else:
      echo "warning: ", "unhandled token while parsing selector: ", tk.repr()
      break

  # echo "\tsel:done"

proc parseBody(parser: CssParser): seq[CssProperty] =

  parser.skip(tkWhiteSpace)
  parser.eat(tkCurlyBracketBlock)

  result.add(CssProperty())

  template popIncompleteProperty(warning = true) =
    if result.len() > 0 and result[^1].name.len() == 0:
      if warning:
        echo "warning: ", "missing css property name! Got: ", result[^1].repr()
      discard result.pop()
    if result.len() > 0 and result[^1].value == MissingCssValue():
      if warning:
        echo "warning: ", "missing css property value! Got: ", result[^1].repr()
      discard result.pop()

  while true:
    parser.skip(tkWhiteSpace)
    var tk = parser.peek()

    # echo "\tproperty:next: ", tk.repr
    case tk.kind:
    of tkIdent:
      discard parser.nextToken()
      if result[^1].name.len() == 0:
        result[^1].name = tk.ident;
        parser.eat(tkColon)
      elif result[^1].value == MissingCssValue():
        result[^1].value = CssVarName(tk.ident)
    of tkIDHash:
      if result[^1].value != MissingCssValue():
        raise newException(ValueError, "expected css hash color to be a property value")
      result[^1].value = CssColor(parseHtmlColor("#" & tk.idHash))
      discard parser.nextToken()
    of tkHash:
      if result[^1].value != MissingCssValue():
        raise newException(ValueError, "expected css hash color to be a property value")
      result[^1].value = CssColor(parseHtmlColor("#" & tk.hash))
      discard parser.nextToken()
    of tkFunction:
      if result[^1].value != MissingCssValue():
        raise newException(ValueError, "expected css hash color to be a property value")
      var value = tk.fnName
      while true:
        tk = parser.nextToken()
        case tk.kind:
        of tkDimension: value &= $tk.dValue
        of tkWhiteSpace: value &= tk.wsStr
        of tkParenBlock: value &= "("
        of tkComma: value &= ","
        of tkCloseParen:
          value &= ")"
          break
        else:
          # echo "\tproperty:other: ", tk.repr
          discard
      # echo "\tproperty function:peek: ", parser.peek().repr
      # echo "\tproperty function: ", value
      # echo "\tproperty function:res: ", result[^1].repr()
      result[^1].value = CssColor(parseHtmlColor(value))
    of tkDimension:
      if result[^1].value != MissingCssValue():
        raise newException(ValueError, "expected css dimension to be a property value")
      let value = csFixed(tk.dValue.UiScalar)
      result[^1].value = CssSize(value)
      discard parser.nextToken()
    of tkPercentage:
      if result[^1].value != MissingCssValue():
        raise newException(ValueError, "expected css percentage to be a property value")
      let value = csPerc(100.0*tk.pUnitValue)
      result[^1].value = CssSize(value)
      discard parser.nextToken()
    of tkSemicolon:
      # echo "\tattrib done "
      popIncompleteProperty()
      discard parser.nextToken()
      result.add(CssProperty())
    of tkCloseCurlyBracket:
      # echo "\tcss block done "
      break
    else:
      # echo "\tattrib:other: ", tk.repr
      echo "warning: ", "unhandled token while parsing property: ", parser.peek().repr
      discard parser.nextToken()

  popIncompleteProperty(warning=false)
  parser.eat(tkCloseCurlyBracket)

proc parse*(parser: CssParser): seq[CssBlock] =

  while not parser.isEof():
    parser.skip(tkWhiteSpace)
    if parser.isEof():
      break
    let sel = parser.parseSelector()
    # echo "selectors: ", sel.repr()
    let props = parser.parseBody()
    # echo ""
    result.add(CssBlock(selectors: sel, properties: props))