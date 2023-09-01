
import common/nodes/ui
import meta/signals
import meta/slots
import ui/core
import ui/apis

export signals, slots
export apis, core, ui

template connect*(
    a: Figuro,
    signal: typed,
    b: Figuro,
    slot: untyped
) =
  when signal == ui.onClick:
    current.listens.mouseSignals.incl(evClick)
    static:
      echo "CONNECT HOOK! :: onClick: ", signal == onClick
  signals.connect(a, signal, b, slot)
