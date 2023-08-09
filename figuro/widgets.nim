
import meta/signals
import meta/slots
import ui/apis

export signals, slots
export apis

type
  Figuro* = ref object of Agent

method render*(widget: Figuro) {.base.} =
  discard

method tick*(widget: Figuro) {.base.} =
  discard

method load*(widget: Figuro) {.base.} =
  discard
