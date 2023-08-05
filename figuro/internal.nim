
import std/locks
import common/nodes/render

type
  MainCallback* = proc() {.nimcall.}

type
  ScaleInfo* = object
    x*: float32
    y*: float32

  UiEvent* = tuple[cond: Cond, lock: Lock]

var
  renderRoot*: Node

  drawMain*: MainCallback
  tickMain*: MainCallback
  loadMain*: MainCallback

  setWindowTitle*: proc (title: string)
  getWindowTitle*: proc (): string

  uiEvent*, renderEvent*: UiEvent

proc initUiEvent*(): UiEvent =
  result.lock.initLock()
  result.cond.initCond()

proc trigger*(evt: var UiEvent) =
  withLock(evt.lock):
    signal(evt.cond)
