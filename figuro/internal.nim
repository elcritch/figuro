
import std/locks
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

type
  UiEvent* = tuple[cond: Cond, lock: Lock]

proc initUiEvent*(): UiEvent =
  result.lock.initLock()
  result.cond.initCond()

proc trigger*(evt: var UiEvent) =
  withLock(evt.lock):
    signal(evt.cond)

var
  renderEvent*: UiEvent
  uiEvent*: UiEvent

proc setupRoot*() =
  if root == nil:
    root = Node()
    root.uid = newUId()
    root.zlevel = ZLevelDefault
  nodeStack = @[root]
  current = root
  root.diffIndex = 0
