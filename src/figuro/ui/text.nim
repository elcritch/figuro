import apis
import chronicles

proc textChanged*(node: Text, txt: string): bool {.thisWrapper.} =
  if node.children.len() == 1:
    node.children[0].hasInnerTextChanged({node.font: txt}, node.hAlign, node.vAlign)
  else:
    true

proc text*(node: Text, spans: openArray[(UiFont, string)]) {.thisWrapper.} =
  if node.children.len() == 1:
    setInnerText(node.children[0], spans, node.hAlign, node.vAlign)
    node.cxMin = node.children[0].cxMin
  else:
    refresh(node)

proc text*(node: Text, text: string) {.thisWrapper.} =
  text(node, {node.font: text})

proc font*(node: Text, font: UiFont) {.thisWrapper.} =
  node.font = font

proc foreground*(node: Text, color: Color) {.thisWrapper.} =
  node.color = color

proc align*(node: Text, kind: FontVertical) {.thisWrapper.} =
  node.vAlign = kind

proc justify*(node: Text, kind: FontHorizontal) {.thisWrapper.} =
  node.hAlign = kind

proc draw*(self: Text) {.slot.} =
  ## Input widget!
  withWidget(self):
    basicText "basicText":
      WidgetContents()
      fill this, self.color
      # this.parent[].cxMin = this.cxMin
