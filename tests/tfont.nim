import pixie

let typeface = readTypeface("examples/data/IBMPlexMono-Bold.ttf")

var font = newFont(typeface)
font.size = size
font.paint = color
let
  arrangement = typeset(@[newSpan(text, font)], bounds = vec2(1280, 800))
  globalBounds = arrangement.computeBounds(transform).snapToPixels()
  textImage = newImage(globalBounds.w.int, globalBounds.h.int)
  imageSpace = translate(-globalBounds.xy) * transform
textImage.fillText(arrangement, imageSpace)