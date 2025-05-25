
## This minimal example shows 5 blue squares.
import figuro/widgets/input
import figuro/widgets/button
import figuro

type
  Main* = ref object of Figuro
    value: float
    hasHovered: bool
    mainRect: Figuro

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Done
  refresh(self.mainRect)


proc draw*(self: Main) {.slot.} =
  withRootWidget(self):
    # self.theme.font = UiFont(typefaceId: self.frame[].theme.font.typefaceId, size: 22)
    Rectangle.new "body":
      self.mainRect = this
      box 10'ux, 10'ux, 600'ux, 120'ux
      cornerRadius 10.0'ui
      fill "#2A9EEA".parseHtmlColor * 0.7
      Input.new "input":
        box 10'ux, 10'ux, 400'ux, 100'ux
        align Middle
        justify Left
        font UiFont(typefaceId: defaultTypeface(), size: 28'ui)
        foreground css"darkred"
        fill css"white"
        clipContent true
        # options({OverwriteMode})
        onInit:
          this.setText "hello world"
          this.text.shiftCursor(TheEnd)
          this.activate()

var main = Main.new()
var frame = newAppFrame(main, size=(720'ui, 140'ui), saveWindowState = false)
startFiguro(frame)
