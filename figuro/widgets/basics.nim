import commons
import ../widget
export widget

proc draw*(self: Rectangle) {.slot.} =
  ## button widget!
  discard

proc draw*(self: Text) {.slot.} =
  ## text widget!
  self.kind = nkText

# exportWidget(basicText, Text)

template new*(t: typedesc[Text], name: untyped, blk: untyped): auto =
  widgetRegister[t](nkText, name, blk)
