import pixie
import pixie/fonts
import figuro/shared
import print

let typeface = readTypeface(DataDirPath / "IBMPlexSans-Regular.ttf")

let text = "lorem ipsum"

var font = newFont(typeface)
font.size = 22
font.paint = parseHtmlColor "#000000"

let
  wh = vec2(1280, 800)
  arrangement = typeset(@[newSpan(text, font)], bounds = wh)
  snappedBounds = arrangement.computeBounds().snapToPixels()
  textImage = newImage(snappedBounds.w.int, snappedBounds.h.int)
  # imageSpace = translate(-snappedBounds.xy) * transform

print arrangement.lines
print arrangement.spans
print arrangement.positions
print arrangement.selectionRects

textImage.fill(rgba(255, 255, 255, 255))

textImage.fillText(arrangement, translate(-snappedBounds.xy))

textImage.writeFile("text.png")
