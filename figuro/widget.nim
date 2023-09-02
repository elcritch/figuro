
import common/nodes/ui
import meta/signals
import meta/slots
import inputs
import ui/core
import ui/apis

export signals, slots
export apis, core, ui, inputs

template connect*(
    a: Figuro,
    signal: typed,
    b: Figuro,
    slot: typed
) =
  when signal == ui.onClick:
    a.listens.mouseSignals.incl {evClick, evClickOut}
  when signal == ui.onHover:
    a.listens.mouseSignals.incl {evHover}
  signals.connect(a, signal, b, slot)
