
import meta/signals
import meta/slots

export signals, slots

type
  Figuro* = ref object of Agent

method render*(widget: Figuro) {.base.} =
  discard

