import ../widget
import ../ui/animations

type GridDebug* = ref object of StatefulFiguro[Color]

proc draw*(self: GridDebug) {.slot.} =
  ## button widget!
  withWidget(self):

    rectangle "contents":
      WidgetContents()

    if node.children.len() > 0 and node.children[0].children.len() > 0:
      let grid = node.children[0].children[0]
      echo "GRID DEBUG"

      ## helper that draws css grid lines. great for debugging layouts.
      rectangle "grid-debug":
        zlevel node, 10.ZLevel
        # strokeLine 3'ui, css"#0000CC"
        # draw debug lines
        # boxOf node, grid.box
        if grid.gridTemplate.isNil:
          echo "GRID NIL"
        else:
          # computeLayout(grid, 0)
          # echo "grid template post: ", grid.gridTemplate
          let cg = grid.gridTemplate.gaps[dcol]
          let wd = 1'ui
          let w = grid.gridTemplate.columns[^1].start.UICoord
          let h = grid.gridTemplate.rows[^1].start.UICoord
          for col in grid.gridTemplate.columns[1 ..^ 2]:
            capture col:
              rectangle "column":
                with node:
                  fill self.state
                  box ux(col.start.UICoord - wd), 0'ux, wd.ux(), h.ux()
          for row in grid.gridTemplate.rows[1 ..^ 2]:
            capture row:
              rectangle "row":
                with node:
                  fill self.state
                  box 0, row.start.UICoord - wd, w.UICoord, wd
          rectangle "edge":
            with node:
              fill self.state
              box 0'ux, 0'ux, w, 3'ux
          rectangle "edge":
            with node:
              fill self.state
              box 0'ux, ux(h - 3), w, 3'ux

# exportWidget(button, Button)
