
import common/nodes/ui
import meta/signals
import meta/slots
import ui/apis

export signals, slots
export apis

type
  Figuro* = ref object of Node

method render*(fig: Figuro) {.base.} =
  discard

method tick*(fig: Figuro) {.base.} =
  discard

method load*(fig: Figuro) {.base.} =
  discard

proc onHover*(fig: Figuro) {.slot.} =
  fig.status.incl onHover
