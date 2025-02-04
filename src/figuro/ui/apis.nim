import nodeapis
export nodeapis

import macros
macro thisWrapper(p: untyped): auto =
  echo "THIS WRAPPER: ", p.treeRepr
  echo "THIS WRAPPER:args: ", p[3].treeRepr
  var args: seq[NimNode]
  for arg in p[3][1..^1]:
    for id in arg[0..^2]:
      args.add(id)
  result = nnkTemplateDef.newTree(p[0..^1])
  result[3].del(1)
  result[^1] = nnkStmtList.newTree(
    newCall(result[0][1], args)
  )
  echo "THIS WRAPPER:result: ", result.repr

# THIS WRAPPER: ProcDef
#   Postfix
#     Ident "*"
#     Ident "boxFrom1"
#   Empty
#   Empty
#   FormalParams
#     Empty
#     IdentDefs
#       Ident "x"
#       Ident "float32"
#       Empty
#     IdentDefs
#       Ident "y"
#       Ident "float32"
#       Empty
#     IdentDefs
#       Ident "w"
#       Ident "float32"
#       Empty
#     IdentDefs
#       Ident "h"
#       Ident "float32"
#       Empty
#   Empty
#   Empty
#   Empty

## ---------------------------------------------
##             Basic Node Creation
## ---------------------------------------------
## 
## Core Fidget Node APIs. These are the main ways to create
## Fidget nodes. 
## 

proc boxFrom*(x, y, w, h: float32) {.thisWrapper.}
  ## Sets the box dimensions.


## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##        Dimension Helpers
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These provide basic dimension units and helpers 
## similar to those available in HTML. They help
## specify details like: "set node width to 100% of it's parents size."
## 

proc box*(
    x: UICoord | Constraint,
    y: UICoord | Constraint,
    w: UICoord | Constraint,
    h: UICoord | Constraint,
) {.thisWrapper.}

proc offset*(x: UICoord | Constraint, y: UICoord | Constraint) {.thisWrapper.}

proc size*(w: UICoord | Constraint, h: UICoord | Constraint) {.thisWrapper.}

proc boxSizeOf*(node: Figuro) {.thisWrapper.}
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`

proc boxOf*(node: Figuro) {.thisWrapper.} =
  discard

proc boxOf*(box: Box) {.thisWrapper.}
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

proc imageStyle*(name: string, color: Color): ImageStyle =
  # Sets teh image style.
  result = ImageStyle(name: name, color: color)

proc setName*(n: string) {.thisWrapper.}
  ## sets current node name

proc border*(weight: UICoord, color: Color) {.thisWrapper.}
  ## Sets border stroke & color on the given node.

proc cssEnable*(enable: bool) {.thisWrapper.}
  ## Causes the parent to clip the children.

proc clipContent*(clip: bool) {.thisWrapper.}
  ## Causes the parent to clip the children.

proc fill*(color: Color) {.thisWrapper.}
  ## Sets background color.

proc zlevel*(zlvl: ZLevel) {.thisWrapper.}
  ## Sets the z-level (layer) height of the given node.

proc fillHover*(color: Color) {.thisWrapper.}
  ## Sets background color.

proc fillHover*(color: Color, alpha: float32) {.thisWrapper.}
  ## Sets background color.

proc positionDiff*(initial: Position, point: Position): Position =
  ## computes relative position of the mouse to the node position

proc positionRelative*(point: Position, node: Figuro): Position =
  ## computes relative position of the mouse to the node position

proc positionRatio*(node: Figuro, point: Position, clamped = false): Position =
  ## computes relative fraction of the mouse's position to the node's area

template onHover*(inner: untyped) {.thisWrapper.}
  ## Code in the block will run when this box is hovered.

template onHover*(inner: untyped) {.thisWrapper.}
  ## Sets and onHover behavior.

proc getTitle*(): string =
  ## Gets window title

template setTitle*(title: string) {.thisWrapper.}
  ## Sets window title

proc cornerRadius*(radius: UICoord) {.thisWrapper.}
  ## Sets all radius of all 4 corners.

proc cornerRadius*(radius: Constraint) {.thisWrapper.}
  ## Sets all radius of all 4 corners.

## ---------------------------------------------
##             Fidget Text APIs
## ---------------------------------------------
## 
## These APIs provide font APIs for Fidget nodes.
## 

proc loadTypeFace*(name: string): TypefaceId =
  ## Sets all radius of all 4 corners.

proc newFont*(typefaceId: TypefaceId): UiFont =
  ## Creates a new UI Font from a given typeface.

proc hasInnerTextChanged*(
    node: Figuro,
    spans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
): bool =
  ## Checks if the text layout has changed.

proc setInnerText*(
    node: Figuro,
    spans: openArray[(UiFont, string)],
    hAlign = FontHorizontal.Left,
    vAlign = FontVertical.Top,
) {.thisWrapper.}
  ## Set the text on an item.

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

proc findGridRow*(index: GridIndex): GridLine {.thisWrapper.}

proc getGridItem(): var GridItem {.thisWrapper.}

proc span*(idx: int | string): GridIndex {.thisWrapper.}

proc columnStart*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid starting column.

proc columnEnd*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

proc gridColumn*[T](val: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

proc rowStart*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid starting row.

proc rowEnd*[T](idx: T) {.thisWrapper.}
  ## Set CSS Grid ending row.

proc gridRow*[T](val: T) {.thisWrapper.}
  ## Set CSS Grid ending column.

proc gridArea*[T](r, c: T) {.thisWrapper.}
  ## CSS Grid shorthand for grid-row-start + grid-column-start + grid-row-end + grid-column-end.

proc gridColumnGap*(value: UICoord) {.thisWrapper.}
  ## Set CSS Grid column gap.

proc gridRowGap*(value: UICoord) {.thisWrapper.}
  ## Set CSS Grid column gap.

proc justifyItems*(con: ConstraintBehavior) {.thisWrapper.}
  ## Justify items on CSS Grid (horizontal)

proc alignItems*(con: ConstraintBehavior) {.thisWrapper.}
  ## Align items on CSS Grid (vertical).

proc layoutItems*(con: ConstraintBehavior) {.thisWrapper.}
  ## Set justification and alignment on child items.

proc layoutItems*(justify, align: ConstraintBehavior) {.thisWrapper.}
  ## Set justification and alignment on child items.

proc gridAutoFlow*(item: GridFlow) {.thisWrapper.}
  ## Sets the CSS Grid auto-flow style.
  ## 
  ## When you have grid items that aren't explicitly placed on the grid,
  ## the auto-placement algorithm kicks in to automatically place the items. 

proc gridAutoColumns*(item: Constraint) {.thisWrapper.}
  ## Specifies the size of any auto-generated grid tracks (aka implicit grid tracks).

proc gridAutoRows*(item: Constraint) {.thisWrapper.}
  ## Specifies the size of any auto-generated grid tracks (aka implicit grid tracks).

