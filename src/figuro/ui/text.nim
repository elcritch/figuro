import apis
import chronicles

proc textChanged*(node: Text, txt: string): bool {.wrapThis.} =
  node.hasInnerTextChanged({node.font: txt}, node.hAlign, node.vAlign)

proc text*(node: Text, spans: openArray[(UiFont, string)]) {.wrapThis.} =
  if node.children.len() == 1:
    setInnerText(node.children[0], spans, node.hAlign, node.vAlign)

proc text*(node: Text, text: string) {.wrapThis.} =
  text(node, {node.font: text})

proc font*(node: Text, font: UiFont) {.wrapThis.} =
  node.font = font

proc foreground*(node: Text, color: Color) {.wrapThis.} =
  node.color = color

proc align*(node: Text, kind: FontVertical) {.wrapThis.} =
  node.vAlign = kind

proc justify*(node: Text, kind: FontHorizontal) {.wrapThis.} =
  node.hAlign = kind

proc draw*(self: Text) {.slot.} =
  ## Input widget!
  withWidget(self):
    basicText "basicText":
      WidgetContents()
      fill this, self.color
