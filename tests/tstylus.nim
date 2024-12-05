## This is a simple example on how to use Stylus' tokenizer.
import std/os, stylus

const src = """

Button {
}

Button.btnBody {
}

Button btnBody {
}

"""

let tokenizer = newTokenizer(src)

type
  CssParser* = ref object
    buff: seq[Token]
    tokenizer: Tokenizer

  CssBlock* = ref object
    selector*: string
    properties*: seq[CssProperty]
  
  CssProperty* = ref object
    name: string
    value: string

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
      echo "skip whitespace"
      discard parser.nextToken()
      continue
    else:
      break

proc parseSelector*(parser: CssParser) =
  parser.skip(tkWhiteSpace)
  var tk = parser.nextToken()
  while tk.kind in [tkIdent]:
    echo "sel: ", tk.repr
    tk = parser.nextToken()
  echo "done"

proc parseBody*(parser: CssParser) =
  parser.skip(tkWhiteSpace)
  parser.eat(tkCurlyBracketBlock)
  parser.skip(tkWhiteSpace)
  parser.eat(tkCloseCurlyBracket)

proc parse*(parser: CssParser) =

  parser.parseSelector()
  parser.parseBody()

  echo "\nrest:"
  while true:
    echo parser.nextToken().repr()

let parser = CssParser(tokenizer: tokenizer)
parse(parser)
