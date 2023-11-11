import std/[algorithm, macros, tables, os]
import std/with
import chroma, bumpy, stack_strings
import cssgrid

import std/[hashes]

import commons, core

export core, cssgrid, stack_strings
export with

template nodes*[T](fig: T, blk: untyped): untyped =
  ## begin drawing nodes
  ## 
  ## sets up the required `current` variable to `fig`
  ## so that the methods from `ui/apis.nim` can 
  ## be used.
  var current {.inject, used.} = fig
  var node {.inject, used.} = fig
  `blk`

template withNodes*[T](fig: T, blk: untyped): untyped =
  ## alias for `nodes`
  nodes[T](fig, blk)

proc init*(tp: typedesc[Stroke], weight: float32|UICoord, color: string, alpha = 1.0): Stroke =
  ## Sets stroke/border color.
  result.color = parseHtmlColor(color)
  result.color.a = alpha
  result.weight = weight.float32

proc init*(tp: typedesc[Stroke], weight: float32|UICoord, color: Color, alpha = 1.0): Stroke =
  ## Sets stroke/border color.
  result.color = color
  result.color.a = alpha
  result.weight = weight.float32

proc imageStyle*(name: string, color: Color): ImageStyle =
  # Image style
  result = ImageStyle(name: name, color: color)

proc strokeLine*(current: Figuro, weight: UICoord, color: Color, alpha = 1.0'f32) =
  ## Sets stroke/border color.
  current.stroke.color = color
  current.stroke.color.a = alpha
  current.stroke.weight = weight.float32

# when not defined(js):
#   func hAlignMode*(align: HAlign): HAlignMode =
#     case align:
#       of hLeft: HAlignMode.Left
#       of hCenter: Center
#       of hRight: HAlignMod.Right

#   func vAlignMode*(align: VAlign): VAlignMode =
#     case align:
#       of vTop: Top
#       of vCenter: Middle
#       of vBottom: Bottom

## ---------------------------------------------
##             Basic Node Creation
## ---------------------------------------------
## 
## Core Fidget Node APIs. These are the main ways to create
## Fidget nodes. 
## 

proc boxFrom*(current: Figuro, x, y, w, h: float32) =
  ## Sets the box dimensions.
  current.box = initBox(x, y, w, h)

# template frame*(id: static string, args: varargs[untyped]): untyped =
#   ## Starts a new frame.
#   nodeImpl(nkFrame, id, args):
#     # boxSizeOf parent
#     discard
#     # current.cxSize = [csAuto(), csAuto()]

# template drawable*(id: static string, inner: untyped): untyped =
#   ## Starts a drawable node. These don't draw a normal rectangle.
#   ## Instead they draw a list of points set in `current.points`
#   ## using the nodes fill/stroke. The size of the drawable node
#   ## is used for the point sizes, etc. 
#   ## 
#   ## Note: Experimental!
#   nodeImpl(nkDrawable, id, inner)

template rectangle*(id: static string, args: varargs[untyped]): untyped =
  ## Starts a new rectangle.
  nodeImpl(nkRectangle, id, args)

template text*(id: string, inner: untyped): untyped =
  ## Starts a new rectangle.
  nodeImpl(nkText, id, inner)

## ---------------------------------------------
##             Fidget Node APIs
## ---------------------------------------------
## 
## These APIs provide the APIs for Fidget nodes.
## 

template `name`*(n: string) =
  ## sets current node name
  current.name.setLen(0)
  current.name.add(n)

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node User Interactions
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## interacting with user interactions. 
## 

type CSSConstraint = Constraint

proc fltOrZero(x: int|float32|float64|UICoord|CSSConstraint): float32 =
  when x is CSSConstraint:
    0.0
  else:
    x.float32

proc csOrFixed*(x: int|float32|float64|UICoord|CSSConstraint): CSSConstraint =
  when x is CSSConstraint:
    x
  else: csFixed(x.UiScalar)

proc box*(
  current: Figuro,
  x: UICoord|CSSConstraint,
  y: UICoord|CSSConstraint,
  w: UICoord|CSSConstraint,
  h: UICoord|CSSConstraint
) =
  ## Sets the size and offsets at the same time
  current.cxOffset = [csOrFixed(x), csOrFixed(y)]
  current.cxSize = [csOrFixed(w), csOrFixed(h)]

# template box*(rect: Box) =
#   ## Sets the box dimensions with integers
#   box(rect.x, rect.y, rect.w, rect.h)

proc offset*(
  current: Figuro, 
  x: UICoord|CSSConstraint,
  y: UICoord|CSSConstraint
) =
  current.cxOffset = [csOrFixed(x), csOrFixed(y)]

proc size*(
  current: Figuro, 
  w: UICoord|CSSConstraint,
  h: UICoord|CSSConstraint,
) =
  current.cxSize = [csOrFixed(w), csOrFixed(h)]

proc boxSizeOf*(current: Figuro, node: Figuro) =
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`
  current.cxSize = [csOrFixed(node.box.w), csOrFixed(node.box.h)]

proc boxOf*(current: Figuro, node: Figuro) =
  current.cxOffset = [csOrFixed(node.box.x), csOrFixed(node.box.y)]
  current.cxSize = [csOrFixed(node.box.w), csOrFixed(node.box.h)]

proc boxOf*(current: Figuro, box: Box) =
  current.cxOffset = [csOrFixed(box.x), csOrFixed(box.y)]
  current.cxSize = [csOrFixed(box.w), csOrFixed(box.h)]

template css*(color: static string): Color =
  const c = parseHtmlColor(color)
  c

proc clipContent*(current: Figuro, clip: bool) =
  ## Causes the parent to clip the children.
  if clip:
    current.attrs.incl clipContent
  else:
    current.attrs.excl clipContent

proc fill*(current: Figuro, color: Color) =
  ## Sets background color.
  current.fill = color
  current.userSetFields.incl fsFill

proc fillHover*(current: Figuro, color: Color) =
  ## Sets background color.
  current.fill = color
  current.userSetFields.incl {fsFill, fsFillHover}

proc fillHover*(current: Figuro, color: Color, alpha: float32) =
  ## Sets background color.
  current.fill = color
  current.fill.a = alpha
  current.userSetFields.incl {fsFill, fsFillHover}

proc positionDiff*(initial: Position, point: Position): Position =
  ## computes relative position of the mouse to the node position
  let x = point.x - initial.x
  let y = point.y - initial.y
  result = initPosition(x.float32, y.float32)

proc positionRelative*(point: Position, node: Figuro): Position =
  ## computes relative position of the mouse to the node position
  let x = point.x - node.screenBox.x
  let y = point.y - node.screenBox.y
  result = initPosition(x.float32, y.float32)

proc positionRatio*(node: Figuro, point: Position, clamped = false): Position =
  ## computes relative fraction of the mouse's position to the node's area
  let track = node.box.wh - point
  result = (point.positionRelative(node) - point/2)/track 
  if clamped:
    result.x = result.x.clamp(0'ui, 1'ui)
    result.y = result.y.clamp(0'ui, 1'ui)

template onHover*(current: Figuro, inner: untyped) =
  ## Code in the block will run when this box is hovered.
  current.listens.events.incl(evHover)
  if evHover in current.events:
    inner
template onHover*(inner: untyped) =
  onHover(current, inner)

template onClick*(current: Figuro, inner: untyped) =
  ## On click event handler.
  current.listens.events.incl(evClick)
  if evClick in current.events.mouse and
      MouseLeft in uxInputs.buttonPress:
    inner
template onClick*(inner: untyped) =
  onClick(current, inner)

template onClickOut*(current: Figuro, inner: untyped) =
  ## On click event handler.
  current.listens.events.incl(evClickOut)
  if evClickOut in current.events.mouse and
      MouseLeft in uxInputs.buttonPress:
    inner
template onClickOut*(current: Figuro, inner: untyped) =
  onClickOut(current, inner)

proc getTitle*(): string =
  ## Gets window title
  getWindowTitle()

template setTitle*(title: string) =
  ## Sets window title
  if (getWindowTitle() != title):
    setWindowTitle(title)
    refresh(current)

proc cornerRadius*(current: Figuro, radius: UICoord) =
  ## Sets all radius of all 4 corners.
  current.cornerRadius = radius
  current.userSetFields.incl fsCornerRadius

proc cornerRadius*(current: Figuro, radius: Constraint) =
  ## Sets all radius of all 4 corners.
  cornerRadius(current, UICoord radius.value.coord)

proc cornerRadius*(current: Figuro, radius: float|float32) =
  cornerRadius(current, UICoord radius)

proc loadTypeFace*(name: string): TypefaceId =
  ## Sets all radius of all 4 corners.
  internal.getTypeface(name)

proc newFont*(typefaceId: TypefaceId): UiFont =
  result = UiFont()
  result.typefaceId = typefaceId
  result.size = 12
  result.lineHeight = -1'ui
  # result.paint = newPaint(SolidPaint)
  # result.paint.color = color(0, 0, 0, 1)

proc setText*(node: Figuro,
              spans: openArray[(UiFont, string)],
              hAlign = FontHorizontal.Left,
              vAlign = FontVertical.Top) =
  # if node.textLayout.isNil:
  node.textLayout = internal.getTypeset(node.box,
                                          spans, hAlign, vAlign)

proc setText*(current: Figuro,
              spans: openArray[(UiFont, string)],
              hAlign = FontHorizontal.Left,
              vAlign = FontVertical.Top) =
  let thash = spans.hash()
  if thash != current.textLayout.contentHash:
    current.textLayout = internal.getTypeset(current.box,
                                             spans, hAlign, vAlign)


## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##        Dimension Helpers
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These provide basic dimension units and helpers 
## similar to those available in HTML. They help
## specify details like: "set node width to 100% of it's parents size."
## 

proc csFixed*(coord: UICoord): Constraint =
  csFixed(coord.UiScalar)

proc ux*(coord: SomeNumber|UICoord): Constraint =
  csFixed(coord.UiScalar)

proc findRoot*(node: Figuro): Figuro =
  result = node
  var cnt = 0
  while result.parent != nil and result != result.parent:
    result = result.parent
    cnt.inc
    if cnt > 10_000:
      raise newException(IndexDefect, "error finding root")

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Layouts and Constraints
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## setting up layouts and constraingts. 
## 

template setGridCols*(current: Figuro, args: untyped) =
  ## configure columns for CSS grid template 
  ## 
  ## the format is `["name"] 40'ui` for each grid line
  ## where
  ##   - `["name"]` is an optional name for each grid line 
  ##   - `40''ui` is a require size for the grid line track
  ## 
  ## the size options are:
  ## - `1'fr` for css grid fractions (e.g. `1'fr 1 fr1` would be ~ 1/2, 1/2)
  ## - `40'ui` UICoord (aka 'pixels'), but helpers like `1'em` work here too
  ## - `auto` whatever is left over
  ## 
  ## names can include multiple names (aliaes):
  ## - `["name", "header-line", "col1" ]` to make layout easier
  ## 
  # layout lmGrid
  parseGridTemplateColumns(current.gridTemplate, args)

template setGridRows*(current: Figuro, args: untyped) =
  ## configure rows for CSS grid template 
  ## 
  ## the format is `["name"] 40'ui` for each grid line
  ## 
  ## where
  ##   - `["name"]` is an optional name for each grid line 
  ##   - `40''ui` is a require size for the grid line track
  ## 
  ## the size options are:
  ## - `1'fr` for css grid fractions (e.g. `1'fr 1 fr1` would be ~ 1/2, 1/2)
  ## - `40'ui` UICoord (aka 'pixels'), but helpers like `1'em` work here too
  ## - `auto` whatever is left over
  ## 
  ## names can include multiple names (aliaes):
  ## - `["name", "header-line", "col1" ]` to make layout easier
  ## 
  parseGridTemplateRows(current.gridTemplate, args)
  # layout lmGrid

template defaultGridTemplate() =
  if current.gridTemplate.isNil:
    current.gridTemplate = newGridTemplate()

template findGridColumn*(index: GridIndex): GridLine =
  defaultGridTemplate()
  current.gridTemplate.getLine(dcol, index)

template findGridRow*(index: GridIndex): GridLine =
  defaultGridTemplate()
  current.gridTemplate.getLine(drow, index)

template getGridItem(): untyped =
  if current.gridItem.isNil:
    current.gridItem = newGridItem()
  current.gridItem

proc span*(idx: int | string): GridIndex =
  mkIndex(idx, isSpan = true)

template columnStart*(current: Figuro, idx: untyped) =
  ## set CSS grid starting column
  getGridItem().index[dcol].a = idx.mkIndex()
template columnEnd*(current: Figuro, idx: untyped) =
  ## set CSS grid ending column
  getGridItem().index[dcol].b = idx.mkIndex()
template gridColumn*(current: Figuro, val: untyped) =
  ## set CSS grid ending column
  getGridItem().column = val

template rowStart*(current: Figuro, idx: untyped) =
  ## set CSS grid starting row
  getGridItem().index[drow].a = idx.mkIndex()
template rowEnd*(current: Figuro, idx: untyped) =
  ## set CSS grid ending row
  getGridItem().index[drow].b = idx.mkIndex()
template gridRow*(current: Figuro, val: untyped) =
  ## set CSS grid ending column
  getGridItem().row = val

template gridArea*(current: Figuro, r, c: untyped) =
  getGridItem().row = r
  getGridItem().column = c

template columnGap*(current: Figuro, value: UICoord) =
  ## set CSS grid column gap
  defaultGridTemplate()
  current.gridTemplate.gaps[dcol] = value.UiScalar

template rowGap*(current: Figuro, value: UICoord) =
  ## set CSS grid column gap
  defaultGridTemplate()
  current.gridTemplate.gaps[drow] = value.UiScalar

template justifyItems*(current: Figuro, con: ConstraintBehavior) =
  ## justify items on css grid (horizontal)
  defaultGridTemplate()
  current.gridTemplate.justifyItems = con
template alignItems*(current: Figuro, con: ConstraintBehavior) =
  ## align items on css grid (vertical)
  defaultGridTemplate()
  current.gridTemplate.alignItems = con
# template justify*(con: ConstraintBehavior) =
#   ## justify items on css grid (horizontal)
#   defaultGridTemplate()
#   current.gridItem.justify = con
# template align*(con: ConstraintBehavior) =
#   ## align items on css grid (vertical)
#   defaultGridTemplate()
#   current.gridItem.align = con
proc layoutItems*(current: Figuro, con: ConstraintBehavior) =
  ## set justification and alignment on child items
  defaultGridTemplate()
  current.gridTemplate.justifyItems = con
  current.gridTemplate.alignItems = con
  current.userSetFields.incl {fsGridAutoColumns, fsGridAutoRows}

proc layoutItems*(current: Figuro, justify, align: ConstraintBehavior) =
  ## set justification and alignment on child items
  defaultGridTemplate()
  current.gridTemplate.justifyItems = justify
  current.gridTemplate.alignItems = align
  current.userSetFields.incl {fsGridAutoColumns, fsGridAutoRows}

proc gridAutoFlow*(current: Figuro, item: GridFlow) =
  defaultGridTemplate()
  current.gridTemplate.autoFlow = item
  current.userSetFields.incl fsGridAutoFlow

proc gridAutoColumns*(current: Figuro, item: Constraint) =
  defaultGridTemplate()
  current.gridTemplate.autos[dcol] = item
  current.userSetFields.incl fsGridAutoColumns
proc gridAutoRows*(current: Figuro, item: Constraint) =
  defaultGridTemplate()
  current.gridTemplate.autos[drow] = item
  current.userSetFields.incl fsGridAutoRows

proc gridTemplateDebugLines*(current: Figuro, grid: Figuro, color: Color = blueColor) =
  ## helper that draws css grid lines. great for debugging layouts.
  rectangle "grid-debug":
    # strokeLine 3'ui, css"#0000CC"
    # draw debug lines
    node.boxOf grid.box
    if not grid.gridTemplate.isNil:
      computeLayout(grid, 0)
      # echo "grid template post: ", grid.gridTemplate
      let cg = grid.gridTemplate.gaps[dcol]
      let wd = 1'ui
      let w = grid.gridTemplate.columns[^1].start.UICoord
      let h = grid.gridTemplate.rows[^1].start.UICoord
      echo "size: ", (w, h)
      for col in grid.gridTemplate.columns[1..^2]:
        rectangle "column", captures(col):
          with node:
            fill color
            box ux(col.start.UICoord - wd), 0'ux, wd.ux(), h.ux()
      for row in grid.gridTemplate.rows[1..^2]:
        rectangle "row", captures(row):
          with node:
            fill color
            box 0, row.start.UICoord - wd, w.UICoord, wd
      rectangle "edge":
        with node:
          fill color.darken(0.5)
          box 0'ux, 0'ux, w, 3'ux
      rectangle "edge":
        with node:
          fill color.darken(0.5)
          box 0'ux, ux(h - 3), w, 3'ux
