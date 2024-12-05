## This is a simple example on how to use Stylus' tokenizer.
import std/os, stylus

const src = """
Button {
  color: rgba(10, 10, 10, 100);
}
"""

let tokenizer = newTokenizer(src)

type
  CssParser* = ref object
    buff: seq[Token]
    tokenizer: Tokenizer

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

proc eat*(parser: CssParser, kind: TokenKind): bool =
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
      echo "not whitespace"
      break

proc parse*(parser: CssParser) =
  parser.skip(tkWhiteSpace)

  let tk = parser.nextToken()
  echo repr tk

  echo "rest:"
  while not tokenizer.isEof():
    echo repr tokenizer.nextToken()

let parser = CssParser(tokenizer: tokenizer)
parse(parser)
