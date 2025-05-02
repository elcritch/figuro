import figuro/ui/animations
import pkg/sigils
import pkg/chronicles
import std/unittest
import std/os

import figuro

type
  TMain* = ref object of Figuro
    amount*: float
    finished*: int

proc draw*(self: TMain) {.slot.} =
  withWidget(self):
    this.setName "main"
    Rectangle.new "body":
      echo "body"

proc tick*(self: TMain, now: MonoTime, delta: Duration) {.slot.} =
  # echo "TICK: ", now, " delta: ", delta
  discard

proc doFadeTick*(self: TMain, value: tuple[amount, perc: float], finished: bool) {.slot.} =
  echo "fade:tick: ", value.repr
  if finished:
    self.amount = value.amount
    self.finished.inc()
# proc fadeDone*(self: TMain, value: tuple[amount, perc: float], finished: bool) {.slot.} =
#   echo "fade:done: ", value.repr
#   self.amount = value.amount
#   self.finished.inc()

suite "animations":

  template setupMain() =
    var main {.inject.} = TMain()
    when defined(sigilsDebug):
      main.debugName = "main"
    var frame = newAppFrame(main, size=(400'ui, 140'ui))
    main.frame = frame.unsafeWeakRef()
    connectDefaults(main)
    emit main.doDraw()

  test "fader basic":
    setupMain()
    let fader = Fader(inTimeMs: 50, outTimeMs: 30)
    when defined(sigilsDebug):
      fader.debugName = "fader"

    fader.connect(doFadeTick, main, TMain.doFadeTick())
    # fader.connect(fadeDone, main, TMain.fadeDone())
    fader.addTarget(main)

    var
      ts: MonoTime
      dur = initDuration(milliseconds = 12)

    for i in 1..20:
      if i == 3:
        fader.fadeIn()
      emit main.doTick(ts, dur)
      ts = ts + dur

      if i < 7:
        check main.finished == 0
      elif i == 7:
        check main.finished == 1
        # echo "check finished: ", i
        check fader.amount == 1.0
      elif i == 8:
        fader.fadeOut()
      elif i == 8+3:
        check main.finished == 2
        # echo "check finished: ", i
        check fader.amount == 0.0
      elif i > 8+3:
        check main.finished == 2
        check fader.amount == 0.0

  test "fader change mid":
    setupMain()
    let fader = Fader(inTimeMs: 100, outTimeMs: 100)
    when defined(sigilsDebug):
      fader.debugName = "fader"

    fader.connect(doFadeTick, main, TMain.doFadeTick())
    # fader.connect(fadeDone, main, TMain.fadeDone())
    fader.addTarget(main)

    var
      ts: MonoTime
      dur = initDuration(milliseconds = 12)
    for i in 1..20:
      if i == 3:
        fader.fadeIn()
      elif i == 6:
        check main.finished == 0
        check fader.amount >= 0.30
        fader.fadeOut()
      
      if i == 9:
        check main.amount == 0.0

      emit main.doTick(ts, dur)
      ts = ts + dur


