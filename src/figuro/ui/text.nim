import apis
import animations
import chronicles

proc textChanged*(node: Text, txt: string): bool =
  node.hasInnerTextChanged({node.font: txt}, node.hAlign, node.vAlign)

proc text*(node: Text, spans: openArray[(UiFont, string)]) =
  if node.children.len() == 1:
    setInnerText(node.children[0], spans, node.hAlign, node.vAlign)

proc text*(node: Text, text: string) =
  text(node, {node.font: text})

proc font*(node: Text, font: UiFont) =
  node.font = font

proc foreground*(node: Text, color: Color) =
  node.color = color

proc align*(node: Text, kind: FontVertical) =
  node.vAlign = kind

proc justify*(node: Text, kind: FontHorizontal) =
  node.hAlign = kind

template textChanged*(txt: string): bool {.wrapThis.}
template text*(spans: openArray[(UiFont, string)]) {.wrapThis.}
template text*(text: string) {.wrapThis.}
template font*(font: UiFont) {.wrapThis.}
template foreground*(color: Color) {.wrapThis.}
template align*(kind: FontVertical) {.wrapThis.}
template justify*(kind: FontHorizontal) {.wrapThis.}

proc draw*(self: Text) {.slot.} =
  ## Input widget!
  withWidget(self):
    basicText "basicText":
      WidgetContents()
      fill this, self.color
