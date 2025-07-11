import apisImpl
export apisImpl

import macros
macro thisWrapper*(p: untyped): auto =
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
  let name = tmpl[0][1]
  tmpl[^1] = nnkStmtList.newTree(
    nnkMixinStmt.newTree(name),
    newCall(tmpl[0][1], args),
  )
  result.add tmpl
  # echo "THIS WRAPPER:result: ", result.treeRepr
  # echo "THIS WRAPPER:result: ", result.repr

## ---------------------------------------------
##             Basic APIs
## ---------------------------------------------

template onInit*(blk: untyped) =
  ## Code in the block will run once when the node is initialized.
  if NfInitialized notin this.flags:
    `blk`

template themeColor*(name: static string): Color =
  ## Returns the current theme.
  let varIdx = this.frame[].theme.cssValues.registerVariable(name)
  var res: CssValue
  if this.frame[].theme.cssValues.resolveVariable(varIdx, res):
    if res.kind == CssValueKind.CssColor:
      res.c
    else:
      blackColor
  else:
    blackColor
    

template themeSize*(name: static string): Constraint =
  ## Returns the current theme.
  let varIdx = this.frame[].theme.cssValues.registerVariable(name)
  var res: CssValue
  if this.frame[].theme.cssValues.resolveVariable(varIdx, res):
    if res.kind == CssValueKind.CssSize:
      res.cx
    else:
      0'ux
  else:
    0'ux

template connect*(
    signal: typed,
    b: Figuro,
    slot: typed,
    acceptVoidSlot: static bool = false,
): void =
  uinodes.connect(this, signal, b, slot, acceptVoidSlot)

template image*(name: string, color: Color = whiteColor) =
  ## Sets the image style.
  this.image = imageStyle(name, color)

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##        Dimension Helpers
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##
## These provide basic dimension units and helpers
## similar to those available in HTML. They help
## specify details like: "set node width to 100% of it's parents size."
##

template box*(
    x: UiScalar | Constraint,
    y: UiScalar | Constraint,
    w: UiScalar | Constraint,
    h: UiScalar | Constraint,
) =
  box(this, csOrFixed(x), csOrFixed(y), csOrFixed(w), csOrFixed(h))

template offset*(x: UiScalar | Constraint, y: UiScalar | Constraint) {.thisWrapper.}

template size*(w: UiScalar | Constraint, h: UiScalar | Constraint) {.thisWrapper.}

template padding*(left, right, top, bottom: Constraint) {.thisWrapper.}
template padding*(all: Constraint) {.thisWrapper.}

template paddingLeft*(v: Constraint) {.thisWrapper.}
template paddingTop*(v: Constraint) {.thisWrapper.}
template paddingRight*(v: Constraint) {.thisWrapper.}
template paddingBottom*(v: Constraint) {.thisWrapper.}
template paddingTB*(t, b: Constraint) {.thisWrapper.}
template paddingLR*(l, r: Constraint) {.thisWrapper.}

proc disabled*(self: Figuro, state: bool) {.thisWrapper.} =
  self.setUserAttr({Attributes.Disabled}, state)
proc disabled*(self: Figuro): bool =
  Disabled in self.userAttrs

proc active*(self: Figuro, state: bool) {.thisWrapper.} =
  self.setUserAttr({Active}, state)
proc active*(self: Figuro): bool =
  Active in self.userAttrs

proc hidden*(self: Figuro, state: bool) {.thisWrapper.} =
  self.setUserAttr({Hidden}, state)
proc hidden*(self: Figuro): bool =
  Hidden in self.userAttrs

proc focusable*(self: Figuro, state: bool) {.thisWrapper.} =
  self.setUserAttr({Focusable}, state)
proc focusable*(self: Figuro): bool =
  Focusable in self.userAttrs

proc checked*(self: Figuro, state: bool) {.thisWrapper.} =
  self.setUserAttr({Checked}, state)
proc checked*(self: Figuro): bool =
  Checked in self.userAttrs

proc selected*(self: Figuro, state: bool) {.thisWrapper.} =
  self.setUserAttr({Selected}, state)
proc selected*(self: Figuro): bool =
  Selected in self.userAttrs

template options*[T: enum](attr: set[T], state: bool = true) =
  mixin setOptions
  this.setOptions(attr, state)

template gridCols*(args: untyped) =
  ## configure columns for CSS Grid template
  ##
  ## the format is `["name"] 40'ui` for each grid line
  ## where
  ##   - `["name"]` is an optional name for each grid line
  ##   - `40''ui` is a require size for the grid line track
  ##
  ## the size options are:
  ## - `1'fr` for CSS Grid fractions (e.g. `1'fr 1 fr1` would be ~ 1/2, 1/2)
  ## - `40'ui` UiScalar (aka 'pixels'), but helpers like `1'em` work here too
  ## - `auto` whatever is left over
  ##
  ## names can include multiple names (aliaes):
  ## - `["name", "header-line", "col1" ]` to make layout easier
  ##
  # layout lmGrid
  parseGridTemplateColumns(this.gridTemplate, args)

template gridRows*(args: untyped) =
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
  ## - `40'ui` UiScalar (aka 'pixels'), but helpers like `1'em` work here too
  ## - `auto` whatever is left over
  ##
  ## names can include multiple names (aliaes):
  ## - `["name", "header-line", "col1" ]` to make layout easier
  ##
  parseGridTemplateRows(this.gridTemplate, args)
  # layout lmGrid

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

template setName*(n: string) {.thisWrapper.}
  ## sets current node name

template border*(weight: UiScalar, color: Color) {.thisWrapper.}
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

template onHover*(inner: untyped) {.thisWrapper.}
  ## Code in the block will run when this box is hovered.

template getTitle*(): string {.thisWrapper.}
  ## Gets window title

template setTitle*(title: string) {.thisWrapper.}
  ## Sets window title

template cornerRadius*(radius: array[DirectionCorners, UiScalar]) {.thisWrapper.}
  ## Sets corner radii

template cornerRadius*(radius: array[DirectionCorners, Constraint]) {.thisWrapper.}
  ## Sets corner radii

template corners*(topLeft = 0'ui, topRight = 0'ui, bottomLeft = 0'ui, bottomRight = 0'ui) =
  ## Sets corner radii
  cornerRadius(this, [dcTopLeft: topLeft, dcTopRight: topRight, dcBottomLeft: bottomLeft, dcBottomRight: bottomRight])

template cornerRadius*(radius: UiScalar) {.thisWrapper.}
  ## Sets all radius of all 4 corners.

template cornerRadius*(radius: Constraint) {.thisWrapper.}
  ## Sets all radius of all 4 corners.

template corners*(topLeft = 0'ux, topRight = 0'ux, bottomLeft = 0'ux, bottomRight = 0'ux) =
  ## Sets corner radii
  cornerRadius(this, [dcTopLeft: topLeft, dcTopRight: topRight,  dcBottomLeft: bottomLeft, dcBottomRight: bottomRight])

## ---------------------------------------------
##             Fidget Text APIs
## ---------------------------------------------
##
## These APIs provide font APIs for Fidget nodes.
##

proc loadTypeFace*(name: string): TypefaceId =
  ## Sets all radius of all 4 corners.
  loadTypeFaceImpl(name)

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Layouts and Constraints
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##
## These APIs provide the basic functionality for
## setting up layouts and constraingts.
##

template findGridColumn*(index: GridIndex): GridLine {.thisWrapper.}

template findGridRow*(index: GridIndex): GridLine {.thisWrapper.}

template span*(idx: int | string): GridIndex {.thisWrapper.}

template columnStart*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid starting column.

template columnEnd*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

template gridColumn*[T](val: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

template gridCol*[T](val: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

template rowStart*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid starting row.

template rowEnd*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid ending row.

template gridRow*[T](val: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

template gridArea*[T](c, r: T) {.thisWrapper.}
  ## CSS Grid shorthand for grid-column-start + grid-column-end + grid-row-start + grid-row-end.

template gridColumnGap*(value: UiScalar) {.thisWrapper.}
  ## Set CSS Grid column gap.

template gridRowGap*(value: UiScalar) {.thisWrapper.}
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
