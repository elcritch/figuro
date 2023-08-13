
import common/nodes/ui
import meta/signals
import meta/slots
import ui/core
import ui/apis

export signals, slots
export apis, core, ui

type
  FiguroApp* = ref object of Figuro

proc onTick*(tp: FiguroApp) {.signal.}
proc onDraw*(tp: FiguroApp) {.signal.}

proc tick*(tp: FiguroApp) {.slot.} =
  emit tp.onTick()

proc draw*(tp: FiguroApp) {.slot.} =
  emit tp.onDraw()
