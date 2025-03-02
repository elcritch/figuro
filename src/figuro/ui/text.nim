import apis
import chronicles
import ../common/system

proc textBoxBox(node: Figuro): UiBox =
  var box = node.box
  if box.w == UiScalar.high or box.w == UiScalar.low:
    box.w = 0.UiScalar
  if box.h == UiScalar.high or box.h == UiScalar.low:
    box.h = 0.UiScalar
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
    debug "setInnertText: ", name = node.name, uid= node.uid, textLayoutBox= node.textLayout.bounding
    echo ""
    refresh(node.parent[])

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
      this.cxSize[drow] = max(cx"auto", cx"min-content")
      fill this, self.color
      # this.parent[].cxMin = this.cxMin

when isMainModule:
  import std/unittest
  import cssgrid/prettyprints

  let
    typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
    deffont = UiFont(typefaceId: typeface, size: 18)

  type TMain* = ref object of Figuro

  proc draw*(self: TMain) {.slot.} =
    withWidget(self):
      Rectangle.new "pane":
        with this:
          setGridCols 1'fr
          gridAutoFlow grRow
          justifyItems CxCenter
          alignItems CxCenter
        with this:
          gridAutoRows cx"min-content"
          gridRowGap 3'ui

        let lh = deffont.getLineHeight()

        for idx in 1..3:
          Rectangle.new "story" & $idx:
            with this:
              size 1'fr, max(ux(1.0*lh.float), cx"max-content")

            Text.new "text":
              this.cxPadOffset[drow] = 10'ux
              this.cxPadSize[drow] = 10'ux
              with this:
                # size 1'fr, ux(2*lh)
                size cx"auto", cx"min-content"
                # size 1'fr, max(ux(1.5*lh.float), cx"min-content")
                offset 10'ux, 0'ux
                foreground blackColor
                justify Left
                align Middle
                text({deffont: "some long story " & $idx})


  suite "text suite":
    template setupMain() =
      var main {.inject.} = TMain.new()
      var frame = newAppFrame(main, size=(400'ui, 140'ui))
      main.frame = frame.unsafeWeakRef()
      main.frame[].theme = Theme(font: defaultFont)
      connectDefaults(main)
      emit main.doDraw()
      let scroll {.inject, used.} = main.children[0]
      let items {.inject, used.} = main.children[0].children[0].children[0]

    test "basic":
      setupMain()
      check scroll.name == "scroll"
      check items.name == "items"
      printLayout(main, cmTerminal)
