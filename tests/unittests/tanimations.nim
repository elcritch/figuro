import figuro/ui/animations
import pkg/sigils
import pkg/chronicles
import std/unittest

import figuro

type
  TMain* = ref object of Figuro

proc draw*(self: TMain) {.slot.} =
  withWidget(self):
    node.name = "main"
    rectangle "body":
      echo "body"

suite "animations":

  template setupMain() =
    var main {.inject.} = TMain()
    var frame = newAppFrame(main, size=(400'ui, 140'ui))
    main.frame = frame.unsafeWeakRef()
    connectDefaults(main)
    emit main.doDraw()

  test "fader":
    setupMain()
    let fader = Fader(on: initDuration(milliseconds=500), off: initDuration(milliseconds=300))
