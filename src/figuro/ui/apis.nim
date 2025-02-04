import apisImpl
export apisImpl

import macros
macro wrapThis*(p: untyped): auto =
  # echo "WRAP THIS: ", p.treeRepr
  let isProc = p.kind == nnkProcDef
  result = newStmtList()
  if isProc:
    result.add p

  var args: seq[NimNode]
  args.add ident("this")
  for arg in p[3][1..^1]:
    for id in arg[0..^3]:
      args.add(id)
  var tmpl = nnkTemplateDef.newTree(p[0..^1])
  if isProc:
    tmpl[3].del(1)
    args.delete(1)
  tmpl[^1] = nnkStmtList.newTree(newCall(tmpl[0][1], args))
  result.add tmpl
  # echo "THIS WRAPPER:result: ", result.treeRepr
  # echo "THIS WRAPPER:result: ", result.repr

## ---------------------------------------------
##             Basic Node Creation
## ---------------------------------------------
## 
## Core Fidget Node APIs. These are the main ways to create
## Fidget nodes. 
## 

template connect*(
    signal: typed,
    b: Figuro,
    slot: typed,
    acceptVoidSlot: static bool = false,
): void =
  uinodes.connect(this, signal, b, slot, acceptVoidSlot)

template boxFrom*(x, y, w, h: float32) {.wrapThis.}
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

template offset*(x: UICoord | Constraint, y: UICoord | Constraint) {.wrapThis.}

template size*(w: UICoord | Constraint, h: UICoord | Constraint) {.wrapThis.}

template boxSizeOf*(node: Figuro) {.wrapThis.}
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`

template boxOf*(node: Figuro) {.wrapThis.}

template boxOf*(box: Box) {.wrapThis.}
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

template setName*(n: string) {.wrapThis.}
  ## sets current node name

template border*(weight: UICoord, color: Color) {.wrapThis.}
  ## Sets border stroke & color on the given node.

template cssEnable*(enable: bool) {.wrapThis.}
  ## Causes the parent to clip the children.

template clipContent*(clip: bool) {.wrapThis.}
  ## Causes the parent to clip the children.

template fill*(color: Color) {.wrapThis.}
  ## Sets background color.

template zlevel*(zlvl: ZLevel) {.wrapThis.}
  ## Sets the z-level (layer) height of the given node.

template fillHover*(color: Color) {.wrapThis.}
  ## Sets background color.

template fillHover*(color: Color, alpha: float32) {.wrapThis.}
  ## Sets background color.

template onHover*(inner: untyped) {.wrapThis.}
  ## Code in the block will run when this box is hovered.

template getTitle*(): string {.wrapThis.}
  ## Gets window title

template setTitle*(title: string) {.wrapThis.}
  ## Sets window title

template cornerRadius*(radius: UICoord) {.wrapThis.}
  ## Sets all radius of all 4 corners.

template cornerRadius*(radius: Constraint) {.wrapThis.}
  ## Sets all radius of all 4 corners.

## ---------------------------------------------
##             Fidget Text APIs
## ---------------------------------------------
## 
## These APIs provide font APIs for Fidget nodes.
## 

proc loadTypeFace*(name: string): TypefaceId =
  ## Sets all radius of all 4 corners.
  loadTypeFaceImpl(name)

proc newFont*(typefaceId: TypefaceId): UiFont =
  ## Creates a new UI Font from a given typeface.
  result = UiFont()
  result.typefaceId = typefaceId
  result.size = 12
  result.lineHeight = -1'ui

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Layouts and Constraints
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## setting up layouts and constraingts. 
## 

template setGridCols*(args: untyped) {.wrapThis.}
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

template setGridRows*(args: untyped) {.wrapThis.}
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

template findGridColumn*(index: GridIndex): GridLine {.wrapThis.}

template findGridRow*(index: GridIndex): GridLine {.wrapThis.}

template span*(idx: int | string): GridIndex {.wrapThis.}

template columnStart*[T](idx: T) {.wrapThis.}
  ## Set CSS Grid starting column.

template columnEnd*[T](idx: T) {.wrapThis.}
  ## Set CSS Grid ending column.

template gridColumn*[T](val: T) {.wrapThis.}
  ## Set CSS Grid ending column.

template rowStart*[T](idx: T) {.wrapThis.}
  ## Set CSS Grid starting row.

template rowEnd*[T](idx: T) {.wrapThis.}
  ## Set CSS Grid ending row.

template gridRow*[T](val: T) {.wrapThis.}
  ## Set CSS Grid ending column.

template gridArea*[T](r, c: T) {.wrapThis.}
  ## CSS Grid shorthand for grid-row-start + grid-column-start + grid-row-end + grid-column-end.

template gridColumnGap*(value: UICoord) {.wrapThis.}
  ## Set CSS Grid column gap.

template gridRowGap*(value: UICoord) {.wrapThis.}
  ## Set CSS Grid column gap.

template justifyItems*(con: ConstraintBehavior) {.wrapThis.}
  ## Justify items on CSS Grid (horizontal)

template alignItems*(con: ConstraintBehavior) {.wrapThis.}
  ## Align items on CSS Grid (vertical).

template layoutItems*(con: ConstraintBehavior) {.wrapThis.}
  ## Set justification and alignment on child items.

template layoutItems*(justify, align: ConstraintBehavior) {.wrapThis.}
  ## Set justification and alignment on child items.

template gridAutoFlow*(item: GridFlow) {.wrapThis.}
  ## Sets the CSS Grid auto-flow style.
  ## 
  ## When you have grid items that aren't explicitly placed on the grid,
  ## the auto-placement algorithm kicks in to automatically place the items. 

template gridAutoColumns*(item: Constraint) {.wrapThis.}
  ## Specifies the size of any auto-generated grid tracks (aka implicit grid tracks).

template gridAutoRows*(item: Constraint) {.wrapThis.}
  ## Specifies the size of any auto-generated grid tracks (aka implicit grid tracks).

