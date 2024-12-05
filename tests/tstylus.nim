## This is a simple example on how to use Stylus' tokenizer.
import std/os, stylus
import patty

const src = """

Button {
}

Button.btnBody {
}

Button child {
}

Button < directChild {
}

"""

let tokenizer = newTokenizer(src)


type
  CssParser* = ref object
    buff: seq[Token]
    tokenizer: Tokenizer

  CssBlock* = ref object
    selector*: seq[CssSelector]
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

proc peek(parser: CssParser): Token =
  if tokenizer.isEof():
    raise newException(Exception, "EOF!")
  if parser.buff.len() == 0:
    parser.buff.add(parser.tokenizer.nextToken())
  parser.buff[0]

proc nextToken(parser: CssParser): Token =
  if tokenizer.isEof():
    raise newException(Exception, "EOF!")
  if parser.buff.len() == 0:
    parser.tokenizer.nextToken()
  else:
    let tk = parser.buff[0]
    parser.buff.del(0)
    tk

proc eat*(parser: CssParser, kind: TokenKind) =
  if tokenizer.isEof():
    raise newException(Exception, "EOF!")
  let tk = parser.nextToken()
  if tk.kind != kind:
    raise newException(Exception, "Expected: " & $kind & " got: " & $tk.kind)

proc skip*(parser: CssParser, kind: TokenKind = tkWhiteSpace) =
  while not tokenizer.isEof():
    let tk = parser.peek()
    if tk.kind == kind:
      echo "\tskip whitespace"
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
      echo "\tsel: ", tk.repr
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
      echo "\tsel: ", "done"
      break
    else:
      echo "\tsel:other: ", tk.repr
      break

  echo "\tsel:done"

proc parseBody*(parser: CssParser) =
  parser.skip(tkWhiteSpace)
  parser.eat(tkCurlyBracketBlock)
  parser.skip(tkWhiteSpace)
  parser.eat(tkCloseCurlyBracket)

proc parse*(parser: CssParser) =

  while not parser.tokenizer.isEof():
    let sels = parser.parseSelector()
    echo "selectors: ", sels.repr()
    parser.parseBody()

  echo "\nrest:"
  while true:
    echo parser.nextToken().repr()

let parser = CssParser(tokenizer: tokenizer)
parse(parser)
