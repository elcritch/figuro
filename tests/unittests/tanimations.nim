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

suite "animations":

  template setupMain() =
    var main {.inject.} = TMain()
    var frame = newAppFrame(main, size=(400'ui, 140'ui))
    main.frame = frame.unsafeWeakRef()
    connectDefaults(main)
    emit main.doDraw()

  test "fader":
    setupMain()
    let fader = Fader(fadeIn: initDuration(milliseconds=50), fadeOut: initDuration(milliseconds=30))

    var last = getMonoTime()
    for i in 1..12:
      os.sleep(10)
      if i == 3:
        fader.fadeIn(main)
      var ts = getMonoTime()
      emit main.doTick(ts, ts-last)
      last = ts
