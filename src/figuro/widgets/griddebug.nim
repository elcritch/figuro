import ../widget
import ../ui/animations

import chronicles

type GridDebug* = ref object of StatefulFiguro[(Color, string)]

proc initialize*(self: GridDebug) {.slot.} =
  echo "griddebug:initialize"
  # self.state = blackColor

proc draw*(self: GridDebug) {.slot.} =
  ## button widget!
  withWidget(self):
    let color = self.state[0]
    let gridName = self.state[1]

    # rectangle "contents":
    #   WidgetContents()
    var gridNode: Figuro
    for c in self.parent[].children:
      echo "C: `", c.name, "` ", c.gridTemplate.unsafeWeakRef
      if c.name == gridName:
        echo "C:found: `", c.name, "` ", c.gridTemplate.unsafeWeakRef
        gridNode = c

    rectangle "grid-debug":

      if gridNode != nil:
        let grid = gridNode
        echo "GRID DEBUG: ", self.state

        ## helper that draws css grid lines. great for debugging layouts.
        # fill node, self.state
        # zlevel node, 10.ZLevel
        # strokeLine 3'ui, css"#0000CC"
        # draw debug lines
        boxOf node, grid.box
        if grid.gridTemplate.isNil:
          echo "GRID NIL"
        else:
          # computeLayout(grid, 0)
          # echo "grid template post: ", grid.gridTemplate
          let cg = grid.gridTemplate.gaps[dcol]
          let wd = 3'ui
          let w = grid.gridTemplate.columns[^1].start.UICoord
          let h = grid.gridTemplate.rows[^1].start.UICoord
          for col in grid.gridTemplate.columns[1 ..^ 2]:
            capture col:
              rectangle "column":
                echo "COL: ", col.start.UICoord - wd, " wd: ", wd
                with node:
                  zlevel 10.ZLevel
                  fill color
                  box ux(col.start.UICoord - wd), 0'ux, wd.ux(), h.ux()
          for row in grid.gridTemplate.rows[1 ..^ 2]:
            capture row:
              rectangle "row":
                echo "ROW: ", row.start.UICoord - wd
                with node:
                  zlevel 10.ZLevel
                  fill color
                  box 0, row.start.UICoord - wd, w.UICoord, wd
          rectangle "edge":
            with node:
              fill color
              box 0'ux, 0'ux, w, 3'ux
          rectangle "edge":
            with node:
              fill color
              box 0'ux, ux(h - 3), w, 3'ux

# exportWidget(button, Button)
