# import std/unittest
import cssgrid
import chronicles

import figuro/widget
import figuro/common/nodes/uinodes
import figuro/common/nodes/render

# import std/unittest
import cssgrid/prettyprints
import figuro/ui/layout

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

      block:
        Rectangle.new "item1":
          with this:
            size 1'fr, cx"auto"
          this.cxPadOffset[drow] = 10'ux
          this.cxPadSize[drow] = 10'ux

          Text.new "text":
            text({deffont: "hello world"})
            # this.cxSize[drow] = 100'ux

        Rectangle.new "item2":
          with this:
            size 1'fr, cx"auto"
          this.cxPadOffset[drow] = 10'ux
          this.cxPadSize[drow] = 10'ux

          Text.new "text":
            text({deffont: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."})
            # this.cxSize[drow] = 100'ux

when isMainModule:

  template setupMain() =
    var main {.inject.} = TMain.new()
    var frame = newAppFrame(main, size=(400'ui, 400'ui))
    main.frame = frame.unsafeWeakRef()
    main.frame[].theme = Theme(font: defaultFont)
    main.cxSize = [200'ux, 400'ux]
    connectDefaults(main)
    emit main.doDraw()

    # while frame.redrawNodes.len() > 0:
    for i in 1..10:
      echo "REDRAWS: ", frame.redrawNodes.len()
      let refresh = frame.redrawNodes
      frame.redrawNodes.clear()
      for rn in refresh:
        # echo "REDRAWS: ", rn.unsafeWeakRef
        emit rn.doDraw()
        computeLayouts(frame.root)
      if frame.redrawNodes.len() == 0:
        break

    let scroll {.inject, used.} = main.children[0]
    # let item1 {.inject, used.} = scroll.children[0]
    # let item2 {.inject, used.} = scroll.children[1]
    # let item3 {.inject, used.} = scroll.children[2]
    let item3 {.inject, used.} = scroll.children[0]

  block:
    # setPrettyPrintMode(cmTerminal)
    defer: setPrettyPrintMode(cmNone)
    setupMain()
    printLayout(main, cmTerminal)
    # check scroll.name == "pane"
    # check item1.name == "item1"
    echo "DONE"