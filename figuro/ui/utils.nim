
from sugar import capture
import macros

macro captureArgs*(args, blk: untyped): untyped =
  result = nnkCommand.newTree(bindSym"capture")
  if args.kind in [nnkSym, nnkIdent]:
    if args.strVal != "void":
      result.add args
  else:
    for arg in args:
      result.add args
  if result.len() == 0:
    result = nnkEmpty.newNimNode
  result.add nnkStmtList.newTree(blk)
  echo "captured: ", result.repr

macro statefulWidgetProc*(): untyped =
  ident(repr(genSym(nskProc, "doPost")))
