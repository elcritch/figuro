import figuro/ui/animations
import pkg/sigils
import pkg/chronicles
import std/unittest
import std/os

import figuro

type
  TMain* = ref object of Figuro

proc draw*(self: TMain) {.slot.} =
  withWidget(self):
    node.name = "main"
    rectangle "body":
      echo "body"

proc tick*(self: TMain, now: MonoTime, delta: Duration) {.slot.} =
  echo "TICK: ", now, " delta: ", delta

proc fadeTick*(self: TMain, value: tuple[amount, perc: float]) {.slot.} =
  echo "fade:tick: ", value.repr
proc fadeDone*(self: TMain, value: tuple[amount, perc: float]) {.slot.} =
  echo "fade:done: ", value.repr

suite "animations":

  template setupMain() =
    var main {.inject.} = TMain()
    when defined(sigilsDebug):
      main.debugName = "main"
    var frame = newAppFrame(main, size=(400'ui, 140'ui))
    main.frame = frame.unsafeWeakRef()
    connectDefaults(main)
    emit main.doDraw()

  test "fader":
    setupMain()
    let fader = Fader(inTime: initDuration(milliseconds=50), outTime: initDuration(milliseconds=30))
    when defined(sigilsDebug):
      fader.debugName = "fader"

    fader.connect(fadeTick, main, TMain.fadeTick())
    fader.connect(fadeDone, main, TMain.fadeDone())

    var last = getMonoTime()
    for i in 1..20:
      os.sleep(10)
      if i == 3:
        # fader.start(main, true)
        fader.fadeIn(main.Figuro)
      var ts = getMonoTime()
      emit main.doTick(ts, ts-last)
      last = ts
