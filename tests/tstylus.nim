## This is a simple example on how to use Stylus' tokenizer.
import stylus
import pretty

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
    skSelectorList

  CssSelector* = ref object
    cssType*: string
    class*: string
    id*: string
    combinator*: CssSelectorKind

  CssProperty* = ref object
    name*: string
    value*: string

proc `==`*(a, b: CssSelector): bool =
  a[] == b[]

proc isEof(parser: CssParser): bool =
  parser.tokenizer.isEof()

proc peek(parser: CssParser): Token =
  if parser.isEof():
    raise newException(Exception, "EOF!")
  if parser.buff.len() == 0:
    parser.buff.add(parser.tokenizer.nextToken())
  parser.buff[0]

proc nextToken(parser: CssParser): Token =
  if parser.isEof():
    raise newException(Exception, "EOF!")
  if parser.buff.len() == 0:
    parser.tokenizer.nextToken()
  else:
    let tk = parser.buff[0]
    parser.buff.del(0)
    tk

proc eat*(parser: CssParser, kind: TokenKind) =
  if parser.isEof():
    raise newException(Exception, "EOF!")
  let tk = parser.nextToken()
  if tk.kind != kind:
    raise newException(Exception, "Expected: " & $kind & " got: " & $tk.kind)

proc skip*(parser: CssParser, kind: TokenKind = tkWhiteSpace) =
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

proc parseSelector*(parser: CssParser): seq[CssSelector] =
  var
    isClass = false
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
        result[0].class = tk.ident
        isClass = false
      elif isDirect:
        if result.len() == 0:
          result.add(CssSelector())
        let tk = parser.nextToken()
        result[0].class = tk.ident
        isDirect = false
        result[^1].combinator = skDirectChild
      else:
        let tk = parser.nextToken()
        result.add(CssSelector(cssType: tk.ident))
        if result.len() >= 2:
          result[^1].combinator = skDescendent
    of tkDelim:
      case tk.delim:
      of '.':
        isClass = true
      of '<':
        isDirect = true
      else:
        echo "\tsel:delim:other: ", tk.repr
      discard parser.nextToken()
    of tkCurlyBracketBlock:
      # echo "\tsel: ", "done"
      break
    else:
      # echo "\tsel:other: ", tk.repr
      break

  # echo "\tsel:done"

proc parseBody*(parser: CssParser): seq[CssProperty] =
  var
    expectValue = false
    expectSemi = false

  parser.skip(tkWhiteSpace)
  parser.eat(tkCurlyBracketBlock)
  while true:
    parser.skip(tkWhiteSpace)
    var tk = parser.peek()
    case tk.kind:
    of tkIdent:
      echo "\tattrib: ", tk.repr

      let tk = parser.nextToken()

      if expectValue:
        result[^1].value = tk.ident;
        expectValue = false
        expectSemi = true
      else:
        result.add(CssProperty(name: tk.ident))
        expectValue = true
    of tkCloseCurlyBracket:
      echo "\tattribs done: ", "done"
      break
    else:
      echo "\tattrib:other: ", tk.repr
      let tk = parser.nextToken()
      discard

  parser.eat(tkCloseCurlyBracket)

proc parse*(parser: CssParser): seq[CssBlock] =

  while not parser.isEof():
    parser.skip(tkWhiteSpace)
    if parser.isEof():
      break
    let sel = parser.parseSelector()
    echo "selectors: ", sel.repr()
    let props = parser.parseBody()
    echo ""
    result.add(CssBlock(selectors: sel, properties: props))


import std/unittest

suite "css parser":

  test "blocks":
    skip()
    const src = """

    Button {
    }

    Button.btnBody {
    }

    Button child {
    }

    Button < directChild {
    }

    Button < directChild.field {
    }

    """

    let tokenizer = newTokenizer(src)
    let parser = CssParser(tokenizer: tokenizer)
    let res = parse(parser)
    check res[0].selectors == @[CssSelector(cssType: "Button")]
    check res[1].selectors == @[CssSelector(cssType: "Button", class: "btnBody")]
    echo "results: ", res[2].selectors.repr
    check res[2].selectors == @[
      CssSelector(cssType: "Button", combinator: skNone),
      CssSelector(cssType: "child", combinator: skDescendent)
    ]

  test "attributes":
    const src = """

    Button {
      color-background: #00a400;
    }

    """

    let tokenizer = newTokenizer(src)
    let parser = CssParser(tokenizer: tokenizer)
    let res = parse(parser)
    echo "results: ", res.repr



