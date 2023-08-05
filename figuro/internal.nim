
import widgets/apis

type
  MainCallback* = proc() {.nimcall.}

type
  ScaleInfo* = object
    x*: float32
    y*: float32

var
  root*: Node
  renderRoot*: Node

  drawMain*: MainCallback
  tickMain*: MainCallback
  loadMain*: MainCallback

proc setupRoot*() =
  if root == nil:
    root = Node()
    root.uid = newUId()
    root.zlevel = ZLevelDefault
  nodeStack = @[root]
  current = root
  root.diffIndex = 0
