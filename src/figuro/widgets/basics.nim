import ../widget
import ../ui/animations

proc textChanged*(node: Text, txt: string): bool =
  node.hasInnerTextChanged({node.font: txt}, node.hAlign, node.vAlign)

proc text*(node: Text, spans: openArray[(UiFont, string)]) =
  setInnerText(node, spans, node.hAlign, node.vAlign)

proc text*(node: Text, text: string) =
  text(node, {node.font: text})

proc font*(node: Text, font: UiFont) =
  node.font = font

proc align*(node: Text, kind: FontVertical) =
  node.vAlign = kind

proc justify*(node: Text, kind: FontHorizontal) =
  node.hAlign = kind
