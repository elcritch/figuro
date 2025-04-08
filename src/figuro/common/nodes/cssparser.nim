import std/[strutils, paths, os]
# import ./apis

import pkg/stylus
import pkg/chronicles

import basics
import cssbasics
import cssvalues

export cssbasics, cssvalues

type
  CssTheme* = ref object
    values*: CssValues
    rules*: seq[CssBlock]

proc `$`*(theme: CssTheme): string =
  ## Convert a CSS theme to its string representation
  if theme == nil or theme.rules.len == 0:
    return ""
  
  for i, rule in theme.rules:
    if i > 0:
      result.add "\n\n"
    result.add $rule

iterator rules*(theme: CssTheme): CssBlock =
  if theme != nil:
    for rule in theme.rules:
      yield rule

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
      # error "parser EOF: ", parserBuff = parser.buff.repr
      raise newException(CssParserEofError, "EOF!")
    parser.buff.add(parser.tokenizer.nextToken())
  parser.buff[0]

proc nextToken(parser: CssParser): Token =
  if parser.buff.len() == 0:
    if parser.isEof():
      raise newException(CssParserEofError, "EOF!")
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

proc skip(parser: CssParser, kind: set[TokenKind] = {tkWhiteSpace}) =
  while not parser.isEof():
    let tk = parser.peek()
    if parser.isEof():
      break
    if tk.kind in kind:
      # echo "\tskip whitespace"
      discard parser.nextToken()
      continue
    else:
      break

proc parseSelector(parser: CssParser): seq[CssSelector] =
  # echo "start: selector parser: "
  var
    isClass = false
    isPseudo = false
    isDirect = false

  while true:
    parser.skip({tkWhiteSpace, tkComment})
    var tk = parser.peek()
    trace "CSS: selector parser: ", tk = tk.repr
    case tk.kind
    of tkIdent:
      trace "CSS: ident: ", ident = tk.ident
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
      if result.len() > 1:
        result[^1].combinator = skDescendent
      if isDirect:
        result[^1].combinator = skDirectChild
        isDirect = false
      tk = parser.nextToken()
    of tkDelim:
      case tk.delim
      of '.':
        isClass = true
      of '>':
        isDirect = true
      else:
        warn "CSS: unhandled delim token while parsing selector: ", tk = tk.repr()
      discard parser.nextToken()
    of tkCurlyBracketBlock:
      # echo "\tsel: ", "done"
      break
    of tkComment:
      # var tk = parser.peek()
      tk = parser.nextToken()
      # echo "TK: ", tk.repr
      # echo "NT: ", nt.repr
      break
    else:
      warn "CSS: unhandled token while parsing selector: ", tk = tk.repr()
      break

  # echo "\tsel:done"

proc parseRuleBody*(parser: CssParser, values: CssValues): seq[CssProperty] {.forbids: [InvalidColor].} =
  parser.skip({tkWhiteSpace})
  parser.eat(tkCurlyBracketBlock)

  result.add(CssProperty())

  template popIncompleteProperty(warning = true) =
    if result.len() > 0 and result[^1].name.len() == 0:
      if warning:
        warn "CSS: Missing css property name!", cssResult = result[^1].repr()
      discard result.pop()
    if result.len() > 0 and result[^1].value == MissingCssValue():
      if warning:
        warn "CSS: Missing css property value!", cssResult = result[^1].repr()
      discard result.pop()

  proc parseBasicValue(tk: var Token): CssValue =
    case tk.kind
    of tkIdent:
      discard parser.nextToken()
      if tk.ident.startsWith("var(") and tk.ident.endsWith(")"):
        result = CssVarName(values.registerVariable(tk.ident.toAtom()))
      else:
        try:
          result = CssColor(parseHtmlColor(tk.ident))
        except InvalidColor:
          result = CssAttribute(tk.ident)
      
    of tkIDHash:
      try:
        result = CssColor(parseHtmlColor("#" & tk.idHash))
      except InvalidColor:
        debug("CSS Warning: invalid color ", color = tk.idHash)
        result = CssColor(parseHtmlColor("black"))
      discard parser.nextToken()
    of tkHash:
      try:
        result = CssColor(parseHtmlColor("#" & tk.hash))
      except InvalidColor:
        debug("CSS Warning: invalid color ", color = tk.hash)
        result = CssColor(parseHtmlColor("black"))
      discard parser.nextToken()
    of tkFunction:
      var value = tk.fnName
      while true:
        tk = parser.nextToken()
        case tk.kind
        of tkDimension:
          value &= $tk.dValue
        of tkIdent:
          value &= tk.ident
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
          trace "CSS: property function:other: ", tk = tk.repr
          discard
      trace "CSS: property function:peek: ", peek = parser.peek().repr, value = value
      if value.startsWith("var(") and value.endsWith(")"):
        result = CssVarName(values.registerVariable(toAtom(value.substr(6, value.len() - 2))))
      else:
        try:
          result = CssColor(parseHtmlColor(value))
        except InvalidColor:
          result = MissingCssValue()
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

  proc parseShadow(tk: var Token): CssValue =
    ## parse css shadow
    ## really oughtta follow https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#formal_syntax
    ## but I only care to handle a few for now
    const
      CssSizeKd = CssValueKind.CssSize
      CssBlack = Color(r:0.0,g:0.0,b:0.0,a:1.0)
    proc cssSizesCount(args: seq[CssValue]): int =
      result = 0
      for arg in args:
        if arg.kind != CssSizeKd:
          break
        result.inc()

    var args: seq[CssValue]
    for i in 1..6:
      parser.skip({tkWhiteSpace, tkComment})
      tk = parser.peek()
      args.add(parseBasicValue(tk))
      parser.skip({tkWhiteSpace, tkComment})
      if parser.peek().kind == tkSemicolon:
        break
    parser.eat(tkSemicolon)

    let parsedargs = args
    result = CssShadow(DropShadow, csFixed(0), csFixed(0), csFixed(0), csFixed(0), CssBlack)
    if args.len() == 0:
      echo "CSS Warning: ", "unhandled css shadow kind: ", parsedargs.repr
      return

    if args[0] == CssAttribute("none"):
      args = args[1..^1]

    if args.len() > 0 and args[0] == CssAttribute("inset"):
      result.sstyle = InnerShadow
      args = args[1..^1]

    let lcnt = args.cssSizesCount()
    if lcnt == 2:
      result = CssShadow(result.sstyle, args[0].cx, args[1].cx, csNone(), csNone(), CssBlack)
    elif lcnt == 3:
      result = CssShadow(result.sstyle, args[0].cx, args[1].cx, args[2].cx, csNone(), CssBlack)
    elif lcnt == 4:
      result = CssShadow(result.sstyle, args[0].cx, args[1].cx, args[2].cx, args[3].cx, CssBlack)
    args = args[lcnt..^1]

    if args.len() == 0:
      return
    elif args[0].kind == CssValueKind.CssColor:
      result.scolor = args[0].c
      args = args[1..^1]

    if args.len() > 0 and args[0] == CssAttribute("inset"):
      result.sstyle = InnerShadow
      args = args[1..^1]

    if args.len() == 0:
      return

    warn("CSS: unhandled css shadow kind", parsedargs = $parsedargs)

  while true:
    parser.skip({tkWhiteSpace, tkComment})
    var tk: Token
    try:
      tk = parser.peek()
    except EofError:
      raise newException(InvalidCssBody, "Invalid CSS Body")

    trace "CSS: rule body parser: ", tk = tk.repr
    case tk.kind
    of tkIdent:
      discard parser.nextToken()
      trace "CSS: rule body parser: ", ident = tk.ident
      if result[^1].name.len() == 0:
        result[^1].name = tk.ident
        parser.eat(tkColon)
        if result[^1].name == "box-shadow":
          result[^1].value = parseShadow(tk)
      elif result[^1].value == MissingCssValue():
        if tk.ident.startsWith("var(") and tk.ident.endsWith(")"):
          result[^1].value = CssVarName(values.registerVariable(tk.ident.toAtom()))
        else:
          try:
            result[^1].value = CssColor(parseHtmlColor(tk.ident))
          except ValueError:
            result[^1].value = CssAttribute(tk.ident)
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
      warn("CSS: unhandled token while parsing property: ", peek = parser.peek())
      tk = parser.nextToken()

  # echo "finished: rule body parsing"
  popIncompleteProperty(warning = false)
  parser.eat(tkCloseCurlyBracket)

proc parse*(parser: CssParser, values: CssValues): seq[CssBlock] =
  while not parser.isEof():
    # echo "CSS Block: "
    parser.skip({tkWhiteSpace, tkComment})
    if parser.isEof():
      break
    var sel: seq[CssSelector]
    try:
      sel = parser.parseSelector()
    except ValueError as e:
      warn "CSS: parsing got value error: ", error = e.msg
      continue
    # echo "selectors: ", sel.repr()
    try:
      let props = parser.parseRuleBody(values)
      # echo ""
      result.add(CssBlock(selectors: sel, properties: props))
    except InvalidCssBody:
      error "CSS: invalid css body", selector = sel.repr
    except ValueError as e:
      error "CSS: error parsing css body", error = e.msg
      continue

proc loadTheme*(parser: CssParser): CssTheme =
  let values = newCssValues()
  result = CssTheme(rules: parser.parse(values), values: values)
