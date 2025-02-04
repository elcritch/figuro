import ../widget
import ../ui/animations
import chronicles

proc textChanged*(node: Text, txt: string): bool =
  node.hasInnerTextChanged({node.font: txt}, node.hAlign, node.vAlign)

proc text*(node: Text, spans: openArray[(UiFont, string)]) =
  setInnerText(node, spans, node.hAlign, node.vAlign)

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

proc draw*(self: Text) {.slot.} =
  ## Input widget!
  withWidget(self):
    widgetRegister[BasicFiguro](nkText, "text"):
      WidgetContents()
      echo "TEXT: color: ", self.color
      fill this, self.color
