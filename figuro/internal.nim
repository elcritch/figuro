
import std/locks
import common/nodes/render as render

type
  MainCallback* = proc() {.nimcall.}

type
  ScaleInfo* = object
    x*: float32
    y*: float32

  UiEvent* = tuple[cond: Cond, lock: Lock]

var
  appMain*: MainCallback
  tickMain*: MainCallback
  loadMain*: MainCallback
  sendRoot*: proc (nodes: sink seq[render.Node]) {.closure.}

  setWindowTitle*: proc (title: string)
  getWindowTitle*: proc (): string

  appEvent*, renderEvent*: UiEvent

proc initUiEvent*(): UiEvent =
  result.lock.initLock()
  result.cond.initCond()

proc trigger*(evt: var UiEvent) =
  withLock(evt.lock):
    signal(evt.cond)

proc wait*(evt: var UiEvent) =
  withLock(evt.lock):
    wait(evt.cond, evt.lock)