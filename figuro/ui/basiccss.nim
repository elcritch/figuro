import std/[strutils, paths, os]
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
  CssShadow(sblur, sx, sy: Constraint, scolor: Color)

type
  EofError* = object of CatchableError
  CssError* = object of CatchableError
  InvalidCssBody* = object of CssError

  CssParser* = ref object
    buff: seq[Token]
    tokenizer: Tokenizer

  CssBlock* = ref object
    selectors*: seq[CssSelector]
    properties*: seq[CssProperty]

  CssSelectorKind* {.pure.} = enum
    skNone
    skDirectChild
    skDescendent
    skPseudo
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
  let data = readFile(file.string)
  result = newCssParser(data)

proc isEof(parser: CssParser): bool =
  parser.tokenizer.isEof()

proc peek(parser: CssParser): Token =
  if parser.buff.len() == 0:
    if parser.isEof():
      echo "parser EOF: ", parser.buff.repr
      raise newException(EofError, "EOF!")
    parser.buff.add(parser.tokenizer.nextToken())
  parser.buff[0]

proc nextToken(parser: CssParser): Token =
  if parser.buff.len() == 0:
    if parser.isEof():
      raise newException(EofError, "EOF!")
    parser.tokenizer.nextToken()
  else:
    let tk = parser.buff[0]
    parser.buff.del(0)
    tk

proc eat(parser: CssParser, kind: TokenKind) =
  # if parser.isEof():
  #   raise newException(EofError, "EOF!")
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
  echo "start: selector parser: "
  var
    isClass = false
    isPseudo = false
    isDirect = false

  while true:
    parser.skip(tkWhiteSpace)
    var tk = parser.peek()
    echo "\t selector parser: ", tk.repr
    case tk.kind
    of tkIdent:
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
      case tk.delim
      of '.':
        isClass = true
      of '<':
        isDirect = true
      else:
        echo "warning: ", "unhandled delim token while parsing selector: ", tk.repr()
      discard parser.nextToken()
    of tkCurlyBracketBlock:
      # echo "\tsel: ", "done"
      break
    of tkComment:
      echo "\tcomment: ", "done"
      # var tk = parser.peek()
      let nt = parser.nextToken()
      echo "TK: ", tk.repr
      # echo "NT: ", nt.repr
      break
    else:
      echo "warning: ", "unhandled token while parsing selector: ", tk.repr()
      break

  # echo "\tsel:done"

proc parseRuleBody*(parser: CssParser): seq[CssProperty] {.forbids: [InvalidColor].} =
  parser.skip(tkWhiteSpace)
  parser.eat(tkCurlyBracketBlock)

  result.add(CssProperty())

  template popIncompleteProperty(warning = true) =
    if result.len() > 0 and result[^1].name.len() == 0:
      if warning:
        echo "CSS Warning: ", "missing css property name! Got: ", result[^1].repr()
      discard result.pop()
    if result.len() > 0 and result[^1].value == MissingCssValue():
      if warning:
        echo "CSS Warning: ", "missing css property value! Got: ", result[^1].repr()
      discard result.pop()

  proc parseBasicValue(tk: var Token): CssValue =
    case tk.kind
    of tkIdent:
      discard parser.nextToken()
      try:
        result = CssColor(parseHtmlColor(tk.ident))
      except InvalidColor:
        # echo "css value not color"
        discard
    of tkIDHash:
      try:
        result = CssColor(parseHtmlColor("#" & tk.idHash))
      except InvalidColor:
        echo "CSS Warning: ", "invalid color `$1` " % [tk.idHash]
        result = CssColor(parseHtmlColor("black"))
      discard parser.nextToken()
    of tkHash:
      try:
        result = CssColor(parseHtmlColor("#" & tk.hash))
      except InvalidColor:
        echo "CSS Warning: ", "invalid color `$1` " % [tk.hash]
        result = CssColor(parseHtmlColor("black"))
      discard parser.nextToken()
    of tkFunction:
      var value = tk.fnName
      while true:
        tk = parser.nextToken()
        case tk.kind
        of tkDimension:
          value &= $tk.dValue
        of tkWhiteSpace:
          value &= tk.wsStr
        of tkParenBlock:
          value &= "("
        of tkComma:
          value &= ","
        of tkCloseParen:
          value &= ")"
          break
        else:
          # echo "\tproperty:other: ", tk.repr
          discard
      # echo "\tproperty function:peek: ", parser.peek().repr
      # echo "\tproperty function: ", value
      # echo "\tproperty function:res: ", result[^1].repr()
      result = CssColor(parseHtmlColor(value))
    of tkDimension:
      let value = csFixed(tk.dValue.UiScalar)
      result = CssSize(value)
      discard parser.nextToken()
    of tkPercentage:
      let value = csPerc(100.0 * tk.pUnitValue)
      result = CssSize(value)
      discard parser.nextToken()
    else:
      raise newException(ValueError, "expected basic css value, got: " & tk.repr)

  while true:
    parser.skip(tkWhiteSpace)
    var tk: Token
    try:
      tk = parser.peek()
    except EofError:
      raise newException(InvalidCssBody, "Invalid CSS Body")

    echo "\t rule body parser: ", tk.repr
    # echo "\tproperty:next: ", tk.repr
    case tk.kind
    of tkIdent:
      discard parser.nextToken()
      if result[^1].name.len() == 0:
        result[^1].name = tk.ident
        parser.eat(tkColon)

        if result[^1].name == "box-shadow":
          var args: seq[CssValue]
          for i in 1..4:
            parser.skip(tkWhiteSpace)
            tk = parser.peek()
            args.add parseBasicValue(tk)
          parser.skip(tkWhiteSpace)
          parser.eat(tkSemicolon)
          if args.len() == 4 and
              args[0].kind == CssValueKind.CssSize and
              args[1].kind == CssValueKind.CssSize and
              args[2].kind == CssValueKind.CssSize and
              args[3].kind == CssValueKind.CssColor:
            result[^1].value = CssShadow(args[0].cx, args[1].cx, args[2].cx, args[3].c)
          else:
            echo "CSS Warning: ",
              "unhandled css shadow kind: ", result[^1].name
      elif result[^1].value == MissingCssValue():
        result[^1].value = CssVarName(tk.ident)
    of tkSemicolon:
      # echo "\tattrib done "
      popIncompleteProperty()
      discard parser.nextToken()
      result.add(CssProperty())
    of tkCloseCurlyBracket:
      # echo "\tcss block done "
      break
    of tkIDHash, tkHash, tkFunction, tkDimension, tkPercentage:
      if result[^1].value != MissingCssValue():
        raise newException(ValueError, "expected empty CSS value. Got: " & result[^1].value.repr)
      result[^1].value = parseBasicValue(tk)
    else:
      # echo "\tattrib:other: ", tk.repr
      echo "CSS Warning: ",
        "unhandled token while parsing property: ", parser.peek().repr
      discard parser.nextToken()

  echo "finished: rule body parsing"
  popIncompleteProperty(warning = false)
  parser.eat(tkCloseCurlyBracket)

proc parse*(parser: CssParser): seq[CssBlock] =
  while not parser.isEof():
    # echo "CSS Block: "
    parser.skip(tkWhiteSpace)
    if parser.isEof():
      break
    var sel: seq[CssSelector]
    try:
      sel = parser.parseSelector()
    except ValueError as e:
      echo "Error: ", "parsing got value error: " & e.msg
      continue
    # echo "selectors: ", sel.repr()
    try:
      let props = parser.parseRuleBody()
      # echo ""
      result.add(CssBlock(selectors: sel, properties: props))
    except InvalidCssBody:
      echo "Error: ", "unable to parse CSS body for " & repr sel
    except ValueError as e:
      echo "Error: ", "css rule parsing got value error: " & e.msg
      continue
