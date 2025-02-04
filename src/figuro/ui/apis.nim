import nodeapis
export nodeapis

import macros
macro thisWrapper(p: untyped): auto =
  # echo "THIS WRAPPER: ", p.treeRepr
  # echo "THIS WRAPPER:args: ", p[3].treeRepr
  var args: seq[NimNode]
  args.add ident("this")
  for arg in p[3][1..^1]:
    for id in arg[0..^3]:
      args.add(id)
  result = nnkTemplateDef.newTree(p[0..^1])
  # result[3].del(1)
  # echo "THIS: tree: ", result[0].treeRepr
  result[^1] = nnkStmtList.newTree(
    newCall(result[0][1], args)
  )
  echo "THIS WRAPPER:result: ", result.repr

## ---------------------------------------------
##             Basic Node Creation
## ---------------------------------------------
## 
## Core Fidget Node APIs. These are the main ways to create
## Fidget nodes. 
## 

template boxFrom*(x, y, w, h: float32) {.thisWrapper.}
  ## Sets the box dimensions.


## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##        Dimension Helpers
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These provide basic dimension units and helpers 
## similar to those available in HTML. They help
## specify details like: "set node width to 100% of it's parents size."
## 

template box*(
    x: UICoord | Constraint,
    y: UICoord | Constraint,
    w: UICoord | Constraint,
    h: UICoord | Constraint,
) =
  box(this, csOrFixed(x), csOrFixed(y), csOrFixed(w), csOrFixed(h))

template offset*(x: UICoord | Constraint, y: UICoord | Constraint) {.thisWrapper.}

template size*(w: UICoord | Constraint, h: UICoord | Constraint) {.thisWrapper.}

template boxSizeOf*(node: Figuro) {.thisWrapper.}
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`

template boxOf*(node: Figuro) {.thisWrapper.}

template boxOf*(box: Box) {.thisWrapper.}
  ## Sets the node's size to the given box.

## ---------------------------------------------
##             Fidget Node APIs
## ---------------------------------------------
## 
## These APIs provide styling APIs for Fidget nodes.
## 

template css*(color: static string): Color =
  ## Parses a CSS style color at compile time.
  const c = parseHtmlColor(color)
  c

template imageStyle*(name: string, color: Color): ImageStyle =
  # Sets teh image style.
  result = ImageStyle(name: name, color: color)

template setName*(n: string) {.thisWrapper.}
  ## sets current node name

template border*(weight: UICoord, color: Color) {.thisWrapper.}
  ## Sets border stroke & color on the given node.

template cssEnable*(enable: bool) {.thisWrapper.}
  ## Causes the parent to clip the children.

template clipContent*(clip: bool) {.thisWrapper.}
  ## Causes the parent to clip the children.

template fill*(color: Color) {.thisWrapper.}
  ## Sets background color.

template zlevel*(zlvl: ZLevel) {.thisWrapper.}
  ## Sets the z-level (layer) height of the given node.

template fillHover*(color: Color) {.thisWrapper.}
  ## Sets background color.

template fillHover*(color: Color, alpha: float32) {.thisWrapper.}
  ## Sets background color.

template positionDiff*(initial: Position, point: Position): Position {.thisWrapper.}
  ## computes relative position of the mouse to the node position

template positionRelative*(point: Position, node: Figuro): Position {.thisWrapper.}
  ## computes relative position of the mouse to the node position

template positionRatio*(node: Figuro, point: Position, clamped = false): Position {.thisWrapper.}
  ## computes relative fraction of the mouse's position to the node's area

template onHover*(inner: untyped) {.thisWrapper.}
  ## Code in the block will run when this box is hovered.

template onHover*(inner: untyped) {.thisWrapper.}
  ## Sets and onHover behavior.

template getTitle*(): string {.thisWrapper.}
  ## Gets window title

template setTitle*(title: string) {.thisWrapper.}
  ## Sets window title

template cornerRadius*(radius: UICoord) {.thisWrapper.}
  ## Sets all radius of all 4 corners.

template cornerRadius*(radius: Constraint) {.thisWrapper.}
  ## Sets all radius of all 4 corners.

## ---------------------------------------------
##             Fidget Text APIs
## ---------------------------------------------
## 
## These APIs provide font APIs for Fidget nodes.
## 

template loadTypeFace*(name: string): TypefaceId {.thisWrapper.}
  ## Sets all radius of all 4 corners.

template newFont*(typefaceId: TypefaceId): UiFont {.thisWrapper.}
  ## Creates a new UI Font from a given typeface.


## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Layouts and Constraints
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## setting up layouts and constraingts. 
## 

template setGridCols*(args: untyped) {.thisWrapper.}
  ## configure columns for CSS Grid template 
  ## 
  ## the format is `["name"] 40'ui` for each grid line
  ## where
  ##   - `["name"]` is an optional name for each grid line 
  ##   - `40''ui` is a require size for the grid line track
  ## 
  ## the size options are:
  ## - `1'fr` for CSS Grid fractions (e.g. `1'fr 1 fr1` would be ~ 1/2, 1/2)
  ## - `40'ui` UICoord (aka 'pixels'), but helpers like `1'em` work here too
  ## - `auto` whatever is left over
  ## 
  ## names can include multiple names (aliaes):
  ## - `["name", "header-line", "col1" ]` to make layout easier
  ## 
  # layout lmGrid

template setGridRows*(args: untyped) {.thisWrapper.}
  ## configure rows for CSS Grid template 
  ## 
  ## the format is `["name"] 40'ui` for each grid line
  ## 
  ## where
  ##   - `["name"]` is an optional name for each grid line 
  ##   - `40''ui` is a require size for the grid line track
  ## 
  ## the size options are:
  ## - `1'fr` for CSS Grid fractions (e.g. `1'fr 1 fr1` would be ~ 1/2, 1/2)
  ## - `40'ui` UICoord (aka 'pixels'), but helpers like `1'em` work here too
  ## - `auto` whatever is left over
  ## 
  ## names can include multiple names (aliaes):
  ## - `["name", "header-line", "col1" ]` to make layout easier
  ## 
  # layout lmGrid

template findGridColumn*(index: GridIndex): GridLine {.thisWrapper.}

template findGridRow*(index: GridIndex): GridLine {.thisWrapper.}

template span*(idx: int | string): GridIndex {.thisWrapper.}

template columnStart*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid starting column.

template columnEnd*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

template gridColumn*[T](val: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

template rowStart*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid starting row.

template rowEnd*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid ending row.

template gridRow*[T](val: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

template gridArea*[T](r, c: T) {.thisWrapper.}
  ## CSS Grid shorthand for grid-row-start + grid-column-start + grid-row-end + grid-column-end.

template gridColumnGap*(value: UICoord) {.thisWrapper.}
  ## Set CSS Grid column gap.

template gridRowGap*(value: UICoord) {.thisWrapper.}
  ## Set CSS Grid column gap.

template justifyItems*(con: ConstraintBehavior) {.thisWrapper.}
  ## Justify items on CSS Grid (horizontal)

template alignItems*(con: ConstraintBehavior) {.thisWrapper.}
  ## Align items on CSS Grid (vertical).

template layoutItems*(con: ConstraintBehavior) {.thisWrapper.}
  ## Set justification and alignment on child items.

template layoutItems*(justify, align: ConstraintBehavior) {.thisWrapper.}
  ## Set justification and alignment on child items.

template gridAutoFlow*(item: GridFlow) {.thisWrapper.}
  ## Sets the CSS Grid auto-flow style.
  ## 
  ## When you have grid items that aren't explicitly placed on the grid,
  ## the auto-placement algorithm kicks in to automatically place the items. 

template gridAutoColumns*(item: Constraint) {.thisWrapper.}
  ## Specifies the size of any auto-generated grid tracks (aka implicit grid tracks).

template gridAutoRows*(item: Constraint) {.thisWrapper.}
  ## Specifies the size of any auto-generated grid tracks (aka implicit grid tracks).

