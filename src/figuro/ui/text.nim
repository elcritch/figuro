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
    wrap = true,
) =
  ## Set the text on an item.
  if hasInnerTextChanged(node, spans, hAlign, vAlign):
    trace "setInnertText", name = node.name, uid= node.uid, box= node.box
    node.textLayout = system.getTypeset(node.box, spans, hAlign, vAlign, minContent = node.cxSize[drow] == csNone(), wrap = wrap)
    let minSize = node.textLayout.minSize
    let maxSize = node.textLayout.maxSize
    let bounding = node.textLayout.bounding

    trace "setInnertText:done", name = node.name, uid= node.uid, box= node.box.wh,
          textLayoutBox= node.textLayout.bounding,
          boxMin= node.cxMin, boxMax= node.cxMax,
          minSize= minSize, maxSize= maxSize

    node.cxMin = [min(ux(minSize.w), node.cxSize[dcol]), csFixed(minSize.h)]
    node.cxMax = [csFixed(maxSize.w), csFixed(maxSize.h)]

    refresh(node.parent[])

proc textChanged*(node: Text, txt: string): bool {.thisWrapper.} =
  if node.children.len() == 1:
    node.children[0].hasInnerTextChanged({node.font: txt}, node.hAlign, node.vAlign)
  else:
    true

proc text*(node: Text, spans: openArray[(UiFont, string)], wrap = true) {.thisWrapper.} =
  setInnerText(node, spans, node.hAlign, node.vAlign, wrap)

proc text*(node: Text, text: string, wrap = true) {.thisWrapper.} =
  text(node, {node.font: text}, wrap)

proc font*(node: Text, f: UiFont) {.thisWrapper.} =
  node.font = f

proc foreground*(node: Text, color: Color) {.thisWrapper.} =
  node.color = color

proc align*(node: Text, kind: FontVertical) {.thisWrapper.} =
  node.vAlign = kind

proc justify*(node: Text, kind: FontHorizontal) =
  node.hAlign = kind

template justify*(kind: FontHorizontal) =
  mixin justify
  justify(this, kind)

proc draw*(self: Text) {.slot.} =
  ## Input widget!
  withWidget(self):
    fill this, self.color
    # this.parent[].cxMin = this.cxMin
