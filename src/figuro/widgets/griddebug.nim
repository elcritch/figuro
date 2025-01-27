import ../widget
import ../ui/animations

import chronicles

type GridDebug* = ref object of StatefulFiguro[(Color, string)]

proc initialize*(self: GridDebug) {.slot.} =
  echo "griddebug:initialize"

proc draw*(self: GridDebug) {.slot.} =
  withWidget(self):
    let color = self.state[0]
    let gridName = self.state[1]

    var gridNode: Figuro
    for c in self.parent[].children:
      if c.name == gridName:
        gridNode = c

    rectangle "grid-debug":

      if gridNode != nil:
        let grid = gridNode

        ## helper that draws css grid lines. great for debugging layouts.
        boxOf node, grid.box
        if not grid.gridTemplate.isNil:
          let cg = grid.gridTemplate.gaps[dcol]
          let wd = 3'ui
          let w = grid.gridTemplate.columns[^1].start.UICoord
          let h = grid.gridTemplate.rows[^1].start.UICoord
          for col in grid.gridTemplate.columns[1 ..^ 2]:
            capture col:
              rectangle "column":
                with node:
                  zlevel 10.ZLevel
                  fill color
                  box ux(col.start.UICoord - wd), 0'ux, wd.ux(), h.ux()
          for row in grid.gridTemplate.rows[1 ..^ 2]:
            capture row:
              rectangle "row":
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
