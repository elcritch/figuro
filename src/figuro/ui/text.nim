import apis
import chronicles
import ../common/system

proc hasInnerTextChanged*(
    node: Figuro,
    spans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
): bool =
  ## Checks if the text layout has changed.
  let thash = getContentHash(node.box.wh, spans, hAlign, vAlign)
  trace "hasInnerTextChanged: ", name = node.name, contentHash = thash, nodeContentHash = node.textLayout.contentHash,
      nodeBox = node.box.wh, spans = spans.hash, hAlign = hAlign, vAlign = vAlign
  result = thash != node.textLayout.contentHash

proc setInnerText*(
    node: Figuro,
    spans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
) =
  ## Set the text on an item.
  if hasInnerTextChanged(node, spans, hAlign, vAlign):
    trace "setInnertText", name = node.name, uid= node.uid, box= node.box
    node.textLayout = system.getTypeset(node.box, spans, hAlign, vAlign, minContent = node.cxSize[drow] == csNone())
    let minSize = node.textLayout.minSize
    let maxSize = node.textLayout.maxSize
    let bounding = node.textLayout.bounding

    node.cxMin = [csFixed(minSize.w), csFixed(minSize.h)]
    node.cxMax = [csFixed(maxSize.w), csFixed(maxSize.h)]
    trace "setInnertText:done", name = node.name, uid= node.uid, box= node.box.wh, textLayoutBox= node.textLayout.bounding
    refresh(node.parent[])

proc textChanged*(node: Text, txt: string): bool {.thisWrapper.} =
  if node.children.len() == 1:
    node.children[0].hasInnerTextChanged({node.font: txt}, node.hAlign, node.vAlign)
  else:
    true

proc text*(node: Text, spans: openArray[(UiFont, string)]) {.thisWrapper.} =
  setInnerText(node, spans, node.hAlign, node.vAlign)

proc text*(node: Text, text: string) {.thisWrapper.} =
  text(node, {node.font: text})

proc font*(node: Text, font: UiFont) {.thisWrapper.} =
  node.font = font

proc foreground*(node: Text, color: Color) =
  node.color = color

template foreground*(color: Color)  =
  mixin foreground
  this.foreground(color)

proc align*(node: Text, kind: FontVertical) {.thisWrapper.} =
  node.vAlign = kind

proc justify*(node: Text, kind: FontHorizontal) {.thisWrapper.} =
  node.hAlign = kind

proc draw*(self: Text) {.slot.} =
  ## Input widget!
  withWidget(self):
    fill this, self.color
    # this.parent[].cxMin = this.cxMin
