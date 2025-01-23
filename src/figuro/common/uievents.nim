import std/locks

type UiEvent* = tuple[cond: Cond, lock: Lock]

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}


var
  uiAppEvent* {.runtimeVar.}: UiEvent
  uiRenderEvent* {.runtimeVar.}: UiEvent

proc initUiEvent*(): UiEvent =
  result.lock.initLock()
  result.cond.initCond()

proc trigger*(evt: var UiEvent) =
  withLock(evt.lock):
    signal(evt.cond)

proc wait*(evt: var UiEvent) =
  withLock(evt.lock):
    wait(evt.cond, evt.lock)