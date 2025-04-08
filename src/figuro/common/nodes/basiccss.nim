import std/[strutils, paths, os]
# import ./apis

import stylus
import patty
import chroma
import chronicles

import cssgrid
import cssgrid/variables
import basics

variantp CssValue:
  MissingCssValue
  CssColor(c: Color)
  CssSize(cx: Constraint)
  CssVarName(id: CssVarId)
  CssShadow(sstyle: ShadowStyle, sx, sy, sblur, sspread: Constraint, scolor: Color)
  CssAttribute(a: string)

type
  CssValues* = ref object of CssVariables
    rootApplied*: bool
    parent*: CssValues
    values*: Table[CssVarId, CssValue]

proc newCssValues*(): CssValues =
  result = CssValues(rootApplied: false)

proc newCssValues*(parent: CssValues): CssValues =
  result = CssValues(rootApplied: parent.rootApplied, parent: parent)

proc setVariable*(vars: CssValues, idx: CssVarId, value: CssValue) =
  let isSize = value.kind == CssValueKind.CssSize
  vars.values[idx] = value
  if isSize:
    variables.setVariable(vars, idx, value.cx.value)

proc setFunction*(vars: CssValues, idx: CssVarId, fun: CssFunc) =
  variables.setFunction(CssVariables(vars), idx, fun)

proc setDefault*(vars: CssValues, idx: CssVarId, value: CssValue) =
  if idx notin vars.values:
    vars.setVariable(idx, value)

proc registerVariable*(vars: CssValues, name: string): CssVarId =
  ## Registers a new CSS variable with the given name
  ## Returns the variable index
  var v = vars
  while v != nil:
    if name in v.names:
      return v.names[name]
    v = v.parent
  result = variables.registerVariable(vars, name)

proc registerVariable*(vars: CssValues, name: string, default: CssValue): CssVarId =
  result = vars.registerVariable(name)
  vars.setDefault(result, default)

proc resolveVariable*(vars: CssValues, varIdx: CssVarId, val: var ConstraintSize): bool =
  if vars.resolveVariable(varIdx, val):
    result = true
  elif vars.parent != nil:
    result = vars.parent.resolveVariable(varIdx, val)

proc lookupVariable(vars: CssValues, varIdx: CssVarId, val: var CssValue, recursive: bool = true): bool =
  if vars != nil and varIdx in vars.values:
    val = vars.values[varIdx]
    return true
  elif vars.parent != nil and recursive:
    result = vars.parent.lookupVariable(varIdx, val, recursive)

proc lookupVariable(vars: CssValues, varName: string, val: var CssValue, recursive: bool = true): bool =
  if vars != nil and varName in vars.names:
    val = vars.values[vars.names[varName]]
    return true
  elif vars.parent != nil and recursive:
    result = vars.parent.lookupVariable(varName, val, recursive)

proc resolveVariable*(vars: CssValues, varIdx: CssVarId, val: var CssValue): bool =
  ## Resolves a constraint size, looking up variables if needed
  var res: CssValue
  if vars != nil and lookupVariable(vars, varIdx, res, recursive = true):
    # Handle recursive variable resolution (up to a limit to prevent cycles)
    var resolveCount = 0
    while res.kind == CssValueKind.CssVarName and resolveCount < 10:
      if lookupVariable(vars, res.id, res, recursive = false):
        inc resolveCount
      else:
        break
    if res.kind == CssValueKind.CssVarName: # Prevent infinite recursion, return a default value
      val = MissingCssValue()
      return false
    else:
      val = res
      return true
  else:
    return false


type
  EofError* = object of CatchableError
  CssError* = object of CatchableError
  InvalidCssBody* = object of CssError

  CssParser* = ref object
    buff: seq[Token]
    tokenizer: Tokenizer

  CssTheme* = ref object
    values*: CssValues
    rules*: seq[CssBlock]

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
    cssType*: string
    class*: string
    id*: string
    combinator*: CssSelectorKind

  CssProperty* = object
    name*: string
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
      n
    CssVarName(n):
      "var(" & $n & ")"
    CssShadow(style, x, y, blur, spread, color):
      fmt"{x} {y} {blur} {spread} {color.toHtmlHex()} {style})"

proc `$`*(vals: seq[CssValue]): string =
  for val in vals:
    result &= " "
    result.add $val

proc `$`*(selector: CssSelector): string =
  ## Convert a selector to its string representation
  result = ""
  if selector.id.len > 0:
    result.add "#" & selector.id
  if selector.cssType.len > 0:
    if selector.combinator == skPseudo:
      result.add ":" & selector.cssType
    else:
      result.add selector.cssType
  if selector.class.len > 0:
    result.add "." & selector.class
  
  case selector.combinator:
    of skDirectChild:
      result.add " > "
    of skDescendent:
      result.add " "
    of skSelectorList:
      result.add ", "
    else:
      discard

proc `$`*(property: CssProperty): string =
  ## Convert a property to its string representation
  if property.name.len > 0:
    result = property.name & ": " & $property.value & ";"

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
        result = CssVarName(values.registerVariable(tk.ident))
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
        result = CssVarName(values.registerVariable(value.substr(6, value.len() - 2)))
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
          result[^1].value = CssVarName(values.registerVariable(tk.ident))
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
