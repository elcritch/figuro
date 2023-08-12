
import std/locks
import common/nodes/render as render

type
  MainCallback* = proc() {.closure.}

type
  ScaleInfo* = object
    x*: float32
    y*: float32

  UiEvent* = tuple[cond: Cond, lock: Lock]

when defined(figuroscript):
  var
    appMain* {.compileTime.}: MainCallback
    tickMain* {.compileTime.}: MainCallback
    loadMain* {.compileTime.}: MainCallback
    sendRoot* {.compileTime.}: proc (nodes: sink seq[render.Node]) {.closure.}
    setWindowTitle* {.compileTime.}: proc (title: string)
    getWindowTitle* {.compileTime.}: proc (): string
    appEvent* {.compileTime.}, renderEvent* {.compileTime.}: UiEvent

else:
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
