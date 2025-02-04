import std/[algorithm, macros, tables, os, hashes, with]
from std/sugar import capture
export with, capture

import pkg/[chroma, bumpy, stack_strings, cssgrid, chronicles]
export cssgrid, stack_strings, constraints

import ../commons
import ../common/system
import ../common/system
import ../common/nodes/[uinodes, basics]
export commons, system, uinodes

import core
export core


# template nodes*[T](fig: T, blk: untyped): untyped =
#   ## begin drawing nodes
#   ## 
#   ## sets up the required `current` variable to `fig`
#   ## so that the methods from `ui/apis.nim` can 
#   ## be used.
#   var node {.inject, used.} = fig
#   `blk`

template withNodes*[T](fig: T, blk: untyped): untyped =
  ## alias for `nodes`
  nodes[T](fig, blk)

proc imageStyle*(name: string, color: Color): ImageStyle =
  # Image style
  result = ImageStyle(name: name, color: color)

proc border*(current: Figuro, weight: UICoord, color: Color) =
  ## Sets border stroke & color.
  current.stroke.color = color
  current.stroke.weight = weight.float32

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

template rectangle*(name: string | static string, blk: untyped) =
  ## Starts a new rectangle.
  widgetRegister[Rectangle](nkRectangle, name, blk)

template basicText*(name: string | static string, blk: untyped) =
  ## Starts a new rectangle.
  widgetRegister[BasicFiguro](nkText, name, blk)

## ---------------------------------------------
##             Fidget Node APIs
## ---------------------------------------------
## 
## These APIs provide the APIs for Fidget nodes.
## 

proc setName*(current: Figuro, n: string) =
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

# type Constraint* = Constraint

proc fltOrZero(x: int | float32 | float64 | UICoord | Constraint): float32 =
  when x is Constraint: 0.0 else: x.float32

proc csOrFixed*(x: int | float32 | float64 | UICoord | Constraint): Constraint =
  when x is Constraint:
    x
  else:
    csFixed(x.UiScalar)

proc box*(
    current: Figuro,
    x: UICoord | Constraint,
    y: UICoord | Constraint,
    w: UICoord | Constraint,
    h: UICoord | Constraint,
) =
  ## Sets the size and offsets at the same time
  current.cxOffset = [csOrFixed(x), csOrFixed(y)]
  current.cxSize = [csOrFixed(w), csOrFixed(h)]

# template box*(rect: Box) =
#   ## Sets the box dimensions with integers
#   box(rect.x, rect.y, rect.w, rect.h)

proc offset*(current: Figuro, x: UICoord | Constraint, y: UICoord | Constraint) =
  current.cxOffset = [csOrFixed(x), csOrFixed(y)]

proc size*(current: Figuro, w: UICoord | Constraint, h: UICoord | Constraint) =
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

proc cssEnable*(current: Figuro, enable: bool) =
  ## Causes the parent to clip the children.
  if enable:
    current.attrs.excl skipCss
  else:
    current.attrs.incl skipCss

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

proc zlevel*(current: Figuro, zlvl: ZLevel) =
  current.zlevel = zlvl

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
  result = (point.positionRelative(node) - point / 2) / track
  if clamped:
    result.x = result.x.clamp(0'ui, 1'ui)
    result.y = result.y.clamp(0'ui, 1'ui)

template onHover*(current: Figuro, inner: untyped) =
  ## Code in the block will run when this box is hovered.
  current.listens.events.incl(evHover)
  if evHover in current.events:
    inner

template onHover*(inner: untyped) =
  onHover(node, inner)

proc getTitle*(current: Figuro): string =
  ## Gets window title
  current.frame[].getWindowTitle()

template setTitle*(current: Figuro, title: string) =
  ## Sets window title
  current.frame[].setWindowTitle(title)

proc cornerRadius*(current: Figuro, radius: UICoord) =
  ## Sets all radius of all 4 corners.
  current.cornerRadius = radius
  current.userSetFields.incl fsCornerRadius

proc cornerRadius*(current: Figuro, radius: Constraint) =
  ## Sets all radius of all 4 corners.
  cornerRadius(current, UICoord radius.value.coord)

## Fonts

proc loadTypeFace*(name: string): TypefaceId =
  ## Sets all radius of all 4 corners.
  system.getTypeface(name)

proc newFont*(typefaceId: TypefaceId): UiFont =
  result = UiFont()
  result.typefaceId = typefaceId
  result.size = 12
  result.lineHeight = -1'ui

proc hasInnerTextChanged*(
    node: Figuro,
    spans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
): bool =
  let thash = getContentHash(node.box, spans, hAlign, vAlign)
  result = thash != node.textLayout.contentHash

proc setInnerText*(
    node: Figuro,
    spans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
) =
  if hasInnerTextChanged(node, spans, hAlign, vAlign):
    trace "setText: ", nodeName = node.name, thash = thash, contentHash = current.textLayout.contentHash
    node.textLayout = system.getTypeset(node.box, spans, hAlign, vAlign)
    refresh(node)

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

proc ux*(coord: SomeNumber | UICoord): Constraint =
  csFixed(coord.UiScalar)

proc findRoot*(node: Figuro): Figuro =
  result = node
  var cnt = 0
  while not result.parent.isNil() and result.unsafeWeakRef() != result.parent:
    withRef result.parent, parent:
      result = parent
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

proc defaultGridTemplate(current: Figuro) =
  if current.gridTemplate.isNil:
    current.gridTemplate = newGridTemplate()

proc findGridColumn*(current: Figuro, index: GridIndex): GridLine =
  current.defaultGridTemplate()
  current.gridTemplate.getLine(dcol, index)

proc findGridRow*(current: Figuro, index: GridIndex): GridLine =
  current.defaultGridTemplate()
  current.gridTemplate.getLine(drow, index)

proc getGridItem(current: Figuro): var GridItem =
  if current.gridItem.isNil:
    current.gridItem = newGridItem()
  current.gridItem

proc span*(idx: int | string): GridIndex =
  mkIndex(idx, isSpan = true)

proc columnStart*[T](current: Figuro, idx: T) =
  ## set CSS grid starting column
  current.getGridItem().index[dcol].a = idx.mkIndex()

proc columnEnd*[T](current: Figuro, idx: T) =
  ## set CSS grid ending column
  current.getGridItem().index[dcol].b = idx.mkIndex()

proc gridColumn*[T](current: Figuro, val: T) =
  ## set CSS grid ending column
  current.getGridItem().column = val

proc rowStart*[T](current: Figuro, idx: T) =
  ## set CSS grid starting row
  current.getGridItem().index[drow].a = idx.mkIndex()

proc rowEnd*[T](current: Figuro, idx: T) =
  ## set CSS grid ending row
  current.getGridItem().index[drow].b = idx.mkIndex()

proc gridRow*[T](current: Figuro, val: T) =
  ## set CSS grid ending column
  current.getGridItem().row = val

proc gridArea*[T](current: Figuro, r, c: T) =
  current.getGridItem().row = r
  current.getGridItem().column = c

proc gridColumnGap*(current: Figuro, value: UICoord) =
  ## set CSS grid column gap
  current.defaultGridTemplate()
  current.gridTemplate.gaps[dcol] = value.UiScalar

proc gridRowGap*(current: Figuro, value: UICoord) =
  ## set CSS grid column gap
  current.defaultGridTemplate()
  current.gridTemplate.gaps[drow] = value.UiScalar

proc justifyItems*(current: Figuro, con: ConstraintBehavior) =
  ## justify items on css grid (horizontal)
  current.defaultGridTemplate()
  current.gridTemplate.justifyItems = con

proc alignItems*(current: Figuro, con: ConstraintBehavior) =
  ## align items on css grid (vertical)
  current.defaultGridTemplate()
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
  current.defaultGridTemplate()
  current.gridTemplate.justifyItems = con
  current.gridTemplate.alignItems = con
  current.userSetFields.incl {fsGridAutoColumns, fsGridAutoRows}

proc layoutItems*(current: Figuro, justify, align: ConstraintBehavior) =
  ## set justification and alignment on child items
  current.defaultGridTemplate()
  current.gridTemplate.justifyItems = justify
  current.gridTemplate.alignItems = align
  current.userSetFields.incl {fsGridAutoColumns, fsGridAutoRows}

proc gridAutoFlow*(current: Figuro, item: GridFlow) =
  current.defaultGridTemplate()
  current.gridTemplate.autoFlow = item
  current.userSetFields.incl fsGridAutoFlow

proc gridAutoColumns*(current: Figuro, item: Constraint) =
  current.defaultGridTemplate()
  current.gridTemplate.autos[dcol] = item
  current.userSetFields.incl fsGridAutoColumns

proc gridAutoRows*(current: Figuro, item: Constraint) =
  current.defaultGridTemplate()
  current.gridTemplate.autos[drow] = item
  current.userSetFields.incl fsGridAutoRows

