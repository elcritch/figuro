
## This minimal example shows 5 blue squares.
import figuro

type
  Main* = ref object of Figuro
    value: float

proc draw*(app: Main) {.slot.} =
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      rectangle "block":
        box 20 + i * 120, 20, 100, 100
        current.fill = parseHtmlColor "#2B9FEA"

var
  app = FiguroApp()
  main = Main()

connect(app, onDraw, main, tminimal.draw)

startFiguro(app, w = 720, h = 140)