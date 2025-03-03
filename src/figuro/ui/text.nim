import apis
import chronicles
import ../common/system

proc textBoxBox(node: Figuro): UiBox =
  var box = node.box
  # if box.w == UiScalar.high or box.w == UiScalar.low:
  #   box.w = 0.UiScalar
  # if box.h == UiScalar.high or box.h == UiScalar.low:
  #   box.h = 0.UiScalar
  result = box
  result.x = 0
  result.y = 0

proc hasInnerTextChanged*(
    node: Figuro,
    spans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
): bool =
  ## Checks if the text layout has changed.
  let thash = getContentHash(node.textBoxBox(), spans, hAlign, vAlign)
  result = thash != node.textLayout.contentHash

proc setInnerText*(
    node: Figuro,
    spans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
) =
  ## Set the text on an item.
  if hasInnerTextChanged(node, spans, hAlign, vAlign):
    let box = node.textBoxBox()
    debug "setInnertText: ", name = node.name, uid= node.uid, box= box
    debug "setInnertText: ", name = node.name, uid= node.uid, cxSize= node.cxSize
    node.textLayout = system.getTypeset(box, spans, hAlign, vAlign)
    let minSize = node.textLayout.minSize
    let maxSize = node.textLayout.maxSize
    let bounding = node.textLayout.bounding

    node.cxMin = [csFixed(minSize.w), csFixed(minSize.h)]
    node.cxMax = [csFixed(maxSize.w), csFixed(maxSize.h)]
    if node.cxSize[drow] == csNone():
      # node.cxSize[drow] = csFixed(bounding.h)
      node.cxMin[drow] = csFixed(bounding.h)
    debug "setInnertText: ", name = node.name, uid= node.uid, textLayoutBox= node.textLayout.bounding
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

proc foreground*(node: Text, color: Color) {.thisWrapper.} =
  node.color = color

proc align*(node: Text, kind: FontVertical) {.thisWrapper.} =
  node.vAlign = kind

proc justify*(node: Text, kind: FontHorizontal) {.thisWrapper.} =
  node.hAlign = kind

proc draw*(self: Text) {.slot.} =
  ## Input widget!
  withWidget(self):
    fill this, self.color
    # this.parent[].cxMin = this.cxMin
