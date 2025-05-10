import std/[macros, tables, with, os]
from std/sugar import capture
export with, capture

import pkg/[chroma, bumpy, stack_strings, cssgrid, chronicles]
export cssgrid, stack_strings, constraints

import ../commons
import ../common/system
import ../common/nodes/[uinodes, basics]
export commons, system, uinodes

import core
export core

import ../common/rchannels

proc imagePath*(name: string): string =
  ## Returns the image path for the given node.
  if name.len == 0:
    return ""
  result = name
  case splitFile(result).ext
  of "":
    result.add ".png"
  of ".png":
    discard
  else:
    raise newException(ValueError, "Only PNG images are supported; got: " & splitFile(result).ext)
  if result.isAbsolute():
    result = result
  else:
    result = absolutePath(figDataDir() / result)

proc imageStyle*(name: string, color: Color): ImageStyle =
  # Sets the image style.
  result.name = name.imagePath()
  result.color = color
  if result.name.fileExists():
    result.id = ImageId(hash(result.name))

proc querySibling*(self: Figuro, name: string): Option[Figuro] =
  ## finds first sibling with name
  for sibling in self.parent.children:
    if sibling.uid != self.uid and sibling.name == name:
      return some sibling
  return Figuro.none

template querySibling*[T: Figuro](name: string): Option[T] =
  ## finds first sibling with name
  querySibling(this, name)

proc queryParent*[T: Figuro](this: Figuro, tp: typedesc[T]): Option[T] =
  ## finds first parent with name
  if this.parent[] of tp:
    return some tp(this.parent[])
  elif this.parent.isNil:
    return
  else:
    return this.parent[].queryParent(tp)

proc queryParent*[T: Figuro](this: Figuro, name: string, tp: typedesc = Figuro): Option[T] =
  ## finds first parent with name
  if this.parent[].name == name and this.parent[] of tp:
    return some tp(this.parent[])
  elif this.parent.isNil:
    return
  else:
    return this.parent[].queryParent(name, tp)

proc queryChild*(this: Figuro, name: string, tp: typedesc = Figuro): Option[tp] =
  ## finds first child with name
  for child in this.children:
    if child.name == name and child of tp:
      return some typeof(tp)(child)
  return none(typeof(tp))

proc queryChild*(this: Figuro, tp: typedesc = Figuro): Option[tp] =
  ## finds first child with type
  for child in this.children:
    if child of tp:
      return some typeof(tp)(child)
  return none(typeof(tp))

proc queryDescendant*(this: Figuro, name: string, tp: typedesc = Figuro): Option[tp] =
  ## finds first descendant with name
  for child in this.children:
    if child.name == name and child of tp:
      return some typeof(tp)(child)

  for child in this.children:
    let result = child.queryDescendant(name, tp)
    if result.isSome:
      return result

  return none(typeof(tp))

## ---------------------------------------------
##             Basic Node Creation
## ---------------------------------------------
## 
## Core Fidget Node APIs. These are the main ways to create
## Fidget nodes. 
## 

# template drawable*(id: static string, inner: untyped): untyped =
#   ## Starts a drawable node. These don't draw a normal rectangle.
#   ## Instead they draw a list of points set in `current.points`
#   ## using the nodes fill/stroke. The size of the drawable node
#   ## is used for the point sizes, etc. 
#   ## 
#   ## Note: Experimental!
#   nodeImpl(nkDrawable, id, inner)

template toAtom*(name: Atom): Atom =
  name

template textContents*(blk: untyped) =
  ## Starts a new rectangle.
  widgetRegister[Text]("text", blk)

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##        Dimension Helpers
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These provide basic dimension units and helpers 
## similar to those available in HTML. They help
## specify details like: "set node width to 100% of it's parents size."
## 

proc csFixed*(coord: UiScalar): Constraint =
  ## Sets a fixed UI Constraint size.
  cssgrid.csFixed(coord.UiScalar)

proc ux*(coord: SomeNumber | UiScalar): Constraint =
  ## Alias for `csFixed`, sets a fixed UI Constraint size.
  cssgrid.csFixed(coord.UiScalar)

proc csOrFixed*(x: int | float32 | float64 | UiScalar | Constraint): Constraint =
  when x is Constraint:
    x
  else:
    cssgrid.csFixed(x.UiScalar)

proc box*(
    current: Figuro,
    x: UiScalar | Constraint,
    y: UiScalar | Constraint,
    w: UiScalar | Constraint,
    h: UiScalar | Constraint,
) =
  ## Sets the size and offsets at the same time
  current.cxOffset = [csOrFixed(x), csOrFixed(y)]
  current.cxSize = [csOrFixed(w), csOrFixed(h)]

proc offset*(current: Figuro, x: UiScalar | Constraint, y: UiScalar | Constraint) =
  current.cxOffset = [csOrFixed(x), csOrFixed(y)]

proc size*(current: Figuro, w: UiScalar | Constraint, h: UiScalar | Constraint) =
  current.cxSize = [csOrFixed(w), csOrFixed(h)]

proc boxOf*(current: Figuro, box: Box) =
  ## Sets the node's size to the given box.
  current.cxOffset = [csOrFixed(box.x), csOrFixed(box.y)]
  current.cxSize = [csOrFixed(box.w), csOrFixed(box.h)]

proc padding*(current: Figuro, left, right, top, bottom: UiScalar | Constraint) =
  current.cxPadOffset = [left, top]
  current.cxPadSize = [bottom, right]

proc padding*(current: Figuro, all: UiScalar | Constraint) =
  current.cxPadOffset = [all, all]
  current.cxPadSize = [all, all]

proc paddingLeft*(current: Figuro, v: Constraint) =
  current.cxPadOffset[dcol] = v
proc paddingTop*(current: Figuro, v: Constraint) =
  current.cxPadOffset[drow] = v
proc paddingRight*(current: Figuro, v: Constraint) =
  current.cxPadSize[dcol] = v
proc paddingBottom*(current: Figuro, v: Constraint) =
  current.cxPadSize[drow] = v
proc paddingTB*(current: Figuro, top, bottom: Constraint) =
  current.cxPadOffset[drow] = top
  current.cxPadSize[drow] = bottom
proc paddingLR*(current: Figuro, left, right: Constraint) =
  current.cxPadOffset[dcol] = left
  current.cxPadSize[dcol] = right

## ---------------------------------------------
##             Fidget Node APIs
## ---------------------------------------------
## 
## These APIs provide styling APIs for Fidget nodes.
## 

proc setName*(current: Figuro, n: string) =
  ## sets current node name
  current.name.setLen(0)
  current.name.add(n)

proc border*(current: Figuro, weight: UiScalar, color: Color) =
  ## Sets border stroke & color on the given node.
  current.stroke.color = color
  current.stroke.weight = weight.float32

proc cssEnable*(current: Figuro, enable: bool) =
  ## Causes the parent to clip the children.
  if enable:
    current.userAttrs.excl SkipCss
  else:
    current.userAttrs.incl SkipCss

proc clipContent*(current: Figuro, clip: bool) =
  ## Causes the parent to clip the children.
  if clip:
    current.flags.incl NfClipContent
  else:
    current.flags.excl NfClipContent

proc fill*(current: Figuro, color: Color) =
  ## Sets background color.
  current.fill = color
  current.fieldSet.incl fsFill

proc zlevel*(current: Figuro, zlvl: ZLevel) =
  ## Sets the z-level (layer) height of the given node.
  current.zlevel = zlvl

proc fillHover*(current: Figuro, color: Color) =
  ## Sets background color.
  current.fill = color
  # current.userAttrs.incl {fsFill, fsFillHover}

proc fillHover*(current: Figuro, color: Color, alpha: float32) =
  ## Sets background color.
  current.fill = color
  current.fill.a = alpha
  # current.userAttrs.incl {fsFill, fsFillHover}

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
  let track = node.box.wh.toPos() - point
  result = (point.positionRelative(node) - point / 2) / track
  if clamped:
    result.x = result.x.clamp(0'ui, 1'ui)
    result.y = result.y.clamp(0'ui, 1'ui)

template onHover*(current: Figuro, inner: untyped) =
  ## Code in the block will run when this box is hovered.
  current.listens.events.incl(evHover)
  if evHover in current.events:
    inner

# template onHover*(inner: untyped) =
#   ## Sets and onHover behavior.
#   onHover(node, inner)

proc getTitle*(current: Figuro): string =
  ## Gets window title
  current.frame[].getWindowTitle()

template setTitle*(current: Figuro, title: string) =
  ## Sets window title
  current.frame[].setWindowTitle(title)

proc cornerRadius*(current: Figuro, radii: array[DirectionCorners, UiScalar]) =
  ## Sets all radius of all 4 corners.
  current.cornerRadius = radii
  current.fieldSet.incl fsCornerRadius

proc cornerRadius*(current: Figuro, radius: UiScalar) =
  ## Sets all radius of all 4 corners.
  cornerRadius(current, [radius, radius, radius, radius])

proc cornerRadius*(current: Figuro, radii: array[DirectionCorners, Constraint]) =
  ## Sets all radius of all 4 corners.
  for corner in DirectionCorners:
    current.cornerRadius[corner] = UiScalar(radii[corner].value.coord)
  current.fieldSet.incl fsCornerRadius

proc cornerRadius*(current: Figuro, radius: Constraint) =
  ## Sets all radius of all 4 corners.
  cornerRadius(current, [radius, radius, radius, radius])

## ---------------------------------------------
##             Fidget Text APIs
## ---------------------------------------------
## 
## These APIs provide font APIs for Fidget nodes.
## 

proc loadTypeFaceImpl*(name: string): TypefaceId =
  ## Sets all radius of all 4 corners.
  system.getTypeface(name)

proc newFont*(typefaceId: TypefaceId): UiFont =
  ## Creates a new UI Font from a given typeface.
  result = UiFont()
  result.typefaceId = typefaceId
  result.size = 12
  result.lineHeightScale = 1.0
  result.lineHeightOverride = -1.0'ui


## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Layouts and Constraints
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## setting up layouts and constraingts. 
## 

template setGridCols*(current: Figuro, args: untyped) =
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
  parseGridTemplateColumns(current.gridTemplate, args)

template setGridRows*(current: Figuro, args: untyped) =
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
  ## Makes a CSS Grid span item.
  mkIndex(idx, isSpan = true)

proc columnStart*[T](current: Figuro, idx: T) =
  ## Set CSS Grid starting column.
  current.getGridItem().index[dcol].a = idx.mkIndex()

proc columnEnd*[T](current: Figuro, idx: T) =
  ## Set CSS Grid ending column.
  current.getGridItem().index[dcol].b = idx.mkIndex()

proc gridColumn*[T](current: Figuro, val: T) =
  ## Set CSS Grid ending column.
  current.getGridItem().column = val

proc gridCol*[T](current: Figuro, val: T) =
  ## Set CSS Grid ending column.
  current.getGridItem().column = val

proc rowStart*[T](current: Figuro, idx: T) =
  ## Set CSS Grid starting row.
  current.getGridItem().index[drow].a = idx.mkIndex()

proc rowEnd*[T](current: Figuro, idx: T) =
  ## Set CSS Grid ending row.
  current.getGridItem().index[drow].b = idx.mkIndex()

proc gridRow*[T](current: Figuro, val: T) =
  ## Set CSS Grid ending column.
  current.getGridItem().row = val

proc gridArea*[T](current: Figuro, c, r: T) =
  ## CSS Grid shorthand for grid-column-start + grid-column-end + grid-row-start + grid-row-end.
  current.getGridItem().row = r
  current.getGridItem().column = c

proc gridColumnGap*(current: Figuro, value: UiScalar) =
  ## Set CSS Grid column gap.
  current.defaultGridTemplate()
  current.gridTemplate.gaps[dcol] = value.UiScalar

proc gridRowGap*(current: Figuro, value: UiScalar) =
  ## Set CSS Grid column gap.
  current.defaultGridTemplate()
  current.gridTemplate.gaps[drow] = value.UiScalar

proc justifyItems*(current: Figuro, con: ConstraintBehavior) =
  ## Justify items on CSS Grid (horizontal)
  current.defaultGridTemplate()
  current.gridTemplate.justifyItems = con

proc alignItems*(current: Figuro, con: ConstraintBehavior) =
  ## Align items on CSS Grid (vertical).
  current.defaultGridTemplate()
  current.gridTemplate.alignItems = con

proc layoutItems*(current: Figuro, con: ConstraintBehavior) =
  ## Set justification and alignment on child items.
  current.defaultGridTemplate()
  current.gridTemplate.justifyItems = con
  current.gridTemplate.alignItems = con
  # current.userAttrs.incl {fsGridAutoColumns, fsGridAutoRows}

proc layoutItems*(current: Figuro, justify, align: ConstraintBehavior) =
  ## Set justification and alignment on child items.
  current.defaultGridTemplate()
  current.gridTemplate.justifyItems = justify
  current.gridTemplate.alignItems = align
  # current.userAttrs.incl {fsGridAutoColumns, fsGridAutoRows}

proc gridAutoFlow*(current: Figuro, item: GridFlow) =
  ## Sets the CSS Grid auto-flow style.
  ## 
  ## When you have grid items that aren't explicitly placed on the grid,
  ## the auto-placement algorithm kicks in to automatically place the items. 
  current.defaultGridTemplate()
  current.gridTemplate.autoFlow = item
  current.fieldSet.incl fsGridAutoFlow

proc gridAutoColumns*(current: Figuro, item: Constraint) =
  ## Specifies the size of any auto-generated grid tracks (aka implicit grid tracks).
  current.defaultGridTemplate()
  current.gridTemplate.autos[dcol] = item
  current.fieldSet.incl fsGridAutoColumns

proc gridAutoRows*(current: Figuro, item: Constraint) =
  ## Specifies the size of any auto-generated grid tracks (aka implicit grid tracks).
  current.defaultGridTemplate()
  current.gridTemplate.autos[drow] = item
  current.fieldSet.incl fsGridAutoRows
