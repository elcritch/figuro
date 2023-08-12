
import std/locks
import common/nodes/render as render

when defined(compilervm):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

type
  MainCallback* = proc() {.closure.}

type
  ScaleInfo* = object
    x*: float32
    y*: float32

  UiEvent* = tuple[cond: Cond, lock: Lock]


var
  setWindowTitle* {.runtimeVar.}: proc (title: string)
  getWindowTitle* {.runtimeVar.}: proc (): string
  appEvent* {.runtimeVar.}: UiEvent
  renderEvent* {.runtimeVar.}: UiEvent


proc initUiEvent*(): UiEvent =
  result.lock.initLock()
  result.cond.initCond()

proc trigger*(evt: var UiEvent) =
  withLock(evt.lock):
    signal(evt.cond)

proc wait*(evt: var UiEvent) =
  withLock(evt.lock):
    wait(evt.cond, evt.lock)
