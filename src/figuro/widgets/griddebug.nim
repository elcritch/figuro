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

    Rectangle.new "grid-debug":

      if gridNode != nil:
        let grid = gridNode
        ## helper that draws css grid lines. great for debugging layouts.
        size 100'pp, 100'pp

        if not grid.gridTemplate.isNil:
          let cg = grid.gridTemplate.gaps[dcol]
          let wd = 3'ui
          let w = grid.gridTemplate.columns[^1].start.UiScalar
          let h = grid.gridTemplate.rows[^1].start.UiScalar
          for col in grid.gridTemplate.columns[1 ..^ 2]:
            capture col:
              Rectangle.new "column":
                zlevel 10.ZLevel
                fill color
                box ux(col.start.UiScalar - wd), 0'ux, wd.ux(), h.ux()
          for row in grid.gridTemplate.rows[1 ..^ 2]:
            capture row:
              Rectangle.new "row":
                zlevel 10.ZLevel
                fill color
                box 0, row.start.UiScalar - wd, w.UiScalar, wd
          Rectangle.new "edge":
            fill color
            zlevel 10.ZLevel
            box 0'ux, 0'ux, w, 3'ux
          Rectangle.new "edge":
            fill color
            zlevel 10.ZLevel
            box 0'ux, ux(h - 3), w, 3'ux
