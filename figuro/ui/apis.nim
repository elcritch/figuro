import chroma, bumpy, stack_strings
import std/[algorithm, macros, tables, os]
import cssgrid

import std/[hashes]

import commons, core

export core, cssgrid, stack_strings


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

template strokeLine*(weight: UICoord, color: Color, alpha = 1.0'f32) =
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

template boxFrom*(x, y, w, h: float32) =
  ## Sets the box dimensions.
  current.box = initBox(x, y, w, h)

template frame*(id: static string, args: varargs[untyped]): untyped =
  ## Starts a new frame.
  node(nkFrame, id, args):
    # boxSizeOf parent
    discard
    # current.cxSize = [csAuto(), csAuto()]

template drawable*(id: static string, inner: untyped): untyped =
  ## Starts a drawable node. These don't draw a normal rectangle.
  ## Instead they draw a list of points set in `current.points`
  ## using the nodes fill/stroke. The size of the drawable node
  ## is used for the point sizes, etc. 
  ## 
  ## Note: Experimental!
  node(nkDrawable, id, inner)

template rectangle*(id: static string, args: varargs[untyped]): untyped =
  ## Starts a new rectangle.
  node(nkRectangle, id, args)

template text*(id: string, inner: untyped): untyped =
  ## Starts a new rectangle.
  node(nkText, id, inner)

## Overloaded Nodes 
## ^^^^^^^^^^^^^^^^
## 
## Various overloaded node APIs

template withDefaultName(name: untyped): untyped =
  template `name`*(inner: untyped): untyped =
    `name`("", inner)

withDefaultName(frame)
withDefaultName(rectangle)
withDefaultName(text)
withDefaultName(drawable)

template rectangle*(color: string|Color) =
  ## Shorthand for rectangle with fill.
  rectangle "":
    box 0, 0, parent.getBox().w, parent.getBox().h
    fill color

template blank*(): untyped =
  ## Starts a new rectangle.
  node(nkComponent, ""):
    discard

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

template box*(
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

template offset*(
  x: UICoord|CSSConstraint,
  y: UICoord|CSSConstraint
) =
  current.cxOffset = [csOrFixed(x), csOrFixed(y)]

template size*(
  w: UICoord|CSSConstraint,
  h: UICoord|CSSConstraint,
) =
  current.cxSize = [csOrFixed(w), csOrFixed(h)]

template boxSizeOf*(node: Figuro) =
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`
  current.cxSize = [csOrFixed(node.box.w), csOrFixed(node.box.h)]

template boxOf*(node: Figuro) =
  current.cxOffset = [csOrFixed(node.box.x), csOrFixed(node.box.y)]
  current.cxSize = [csOrFixed(node.box.w), csOrFixed(node.box.h)]

template boxOf*(box: Box) =
  current.cxOffset = [csOrFixed(box.x), csOrFixed(box.y)]
  current.cxSize = [csOrFixed(box.w), csOrFixed(box.h)]

# proc setWindowBounds*(min, max: Vec2) =
#   base.setWindowBounds(min, max)

# proc loadFontAbsolute*(name: string, pathOrUrl: string) =
#   ## Loads fonts anywhere in the system.
#   ## Not supported on js, emscripten, ios or android.
#   if pathOrUrl.endsWith(".svg"):
#     fonts[name] = readFontSvg(pathOrUrl)
#   elif pathOrUrl.endsWith(".ttf"):
#     fonts[name] = readFontTtf(pathOrUrl)
#   elif pathOrUrl.endsWith(".otf"):
#     fonts[name] = readFontOtf(pathOrUrl)
#   else:
#     raise newException(Exception, "Unsupported font format")

# proc loadFont*(name: string, pathOrUrl: string) =
#   ## Loads the font from the dataDir.
#   loadFontAbsolute(name, dataDir / pathOrUrl)

type
  ApiOptions* = enum
    optional

template css*(color: static string): Color =
  const c = parseHtmlColor(color)
  c

template hasAttr*(attr: Attributes): bool =
  attr in current.attrs 

template notAttr*(attr: Attributes): bool =
  attr notin current.attrs 

template clipContent*(clip: bool) =
  ## Causes the parent to clip the children.
  if clip:
    current.attrs.excl noClipContent
  else:
    current.attrs.incl noClipContent

template fill*(color: Color, optional=false) =
  ## Sets background color.
  if not optional or fillSet notin current.attrs:
    current.fill = color
    current.attrs.incl fillSet

template fill*(color: Color, alpha: float32, optional=false) =
  ## Sets background color.
  if not optional or fillSet notin current.attrs:
    current.fill = color
    current.fill.a = alpha
    current.attrs.incl fillSet

template fill*(color: string, alpha: float32 = 1.0, optional=false) =
  ## Sets background color.
  if not optional or fillSet notin current.attrs:
    current.fill = parseHtmlColor(color)
    current.fill.a = alpha
    current.attrs.incl fillSet

template fill*(node: Figuro, optional=true) =
  ## Sets background color.
  if not optional or fillSet notin current.attrs:
    current.fill = node.fill
    current.attrs.incl fillSet

template fillHover*(color: Color, optional=true) =
  ## Sets background color.
  if not optional or fillHoverSet notin current.attrs:
    current.fill = color
    current.attrs.incl {fillSet, fillHoverSet}

template fillHover*(color: Color, alpha: float32, optional=true) =
  ## Sets background color.
  if not optional or fillHoverSet notin current.attrs:
    current.fill = color
    current.fill.a = alpha
    current.attrs.incl {fillSet, fillHoverSet}

# template callHover*(inner: untyped) =
#   ## Code in the block will run when this box is hovered.
#   proc doHover(obj: Figuro) {.slot.} =
#     echo "hi"
#     `inner`
#   root.connect(onHover, current, doHover)

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

template onHover*(inner: untyped) =
  ## Code in the block will run when this box is hovered.
  current.listens.events.incl(evHover)
  if evHover in current.events:
    inner

template onClick*(inner: untyped) =
  ## On click event handler.
  current.listens.events.incl(evClick)
  if evClick in current.events.mouse and
      MouseLeft in uxInputs.buttonPress:
    inner

template onClickOut*(inner: untyped) =
  ## On click event handler.
  current.listens.events.incl(evClickOut)
  if evClickOut in current.events.mouse and
      MouseLeft in uxInputs.buttonPress:
    inner

proc getTitle*(): string =
  ## Gets window title
  getWindowTitle()

template setTitle*(title: string) =
  ## Sets window title
  if (getWindowTitle() != title):
    setWindowTitle(title)
    refresh(current)

template cornerRadius*(radius: UICoord, optional=true) =
  ## Sets all radius of all 4 corners.
  if not optional or cornerRadiusSet notin current.attrs:
    current.cornerRadius = UICoord radius

template cornerRadius*(radius: float|float32, optional=true) =
  if not optional or cornerRadiusSet notin current.attrs:
    cornerRadius(UICoord radius)

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
  if node.textLayout.isNil:
    node.textLayout = internal.getTypeset(node.box,
                                          spans, hAlign, vAlign)

template setText*(spans: openArray[(UiFont, string)],
                  hAlign = FontHorizontal.Left,
                  vAlign = FontVertical.Top) =
  let thash = spans.hash()
  if current.textLayout.isNil or thash != current.textLayout.contentHash:
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

# template Em*(size: float32): UICoord =
#   ## unit size relative to current font size
#   current.textStyle.fontSize * size.UICoord

# proc `'em`*(n: string): UICoord =
#   ## numeric literal em unit
#   result = Em(parseFloat(n))

proc csFixed*(coord: UICoord): Constraint =
  csFixed(coord.UiScalar)

proc ux*(coord: SomeNumber|UICoord): Constraint =
  csFixed(coord.UiScalar)

{.hint[Name]:off.}

proc findRoot*(node: Figuro): Figuro =
  result = node
  var cnt = 0
  while result.parent != nil and result != result.parent:
    result = result.parent
    cnt.inc
    if cnt > 10_000:
      raise newException(IndexDefect, "error finding root")

# template Vw*(size: float32): UICoord =
#   ## percentage of Viewport width
#   current.attrs.incl rxWindowResize
#   app.windowSize.x * size.UICoord / 100.0

# template Vh*(size: float32): UICoord =
#   ## percentage of Viewport height
#   current.attrs.incl rxWindowResize
#   app.windowSize.y * size.UICoord / 100.0

# template `'vw`*(n: string): UICoord =
#   ## numeric literal view width unit
#   Vw(parseFloat(n))

# template `'vh`*(n: string): UICoord =
#   ## numeric literal view height unit
#   Vh(parseFloat(n))

{.hint[Name]:on.}

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Layouts and Constraints
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## setting up layouts and constraingts. 
## 

template setGridCols*(args: untyped) =
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

template setGridRows*(args: untyped) =
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

template columnStart*(idx: untyped) =
  ## set CSS grid starting column 
  getGridItem().index[dcol].a = idx.mkIndex()
template columnEnd*(idx: untyped) =
  ## set CSS grid ending column 
  getGridItem().index[dcol].b = idx.mkIndex()
template gridColumn*(val: untyped) =
  ## set CSS grid ending column 
  getGridItem().column = val

template rowStart*(idx: untyped) =
  ## set CSS grid starting row 
  getGridItem().index[drow].a = idx.mkIndex()
template rowEnd*(idx: untyped) =
  ## set CSS grid ending row 
  getGridItem().index[drow].b = idx.mkIndex()
template gridRow*(val: untyped) =
  ## set CSS grid ending column
  getGridItem().row = val

template gridArea*(r, c: untyped) =
  getGridItem().row = r
  getGridItem().column = c

template columnGap*(value: UICoord) =
  ## set CSS grid column gap
  defaultGridTemplate()
  current.gridTemplate.gaps[dcol] = value.UiScalar

template rowGap*(value: UICoord) =
  ## set CSS grid column gap
  defaultGridTemplate()
  current.gridTemplate.gaps[drow] = value.UiScalar

template justifyItems*(con: ConstraintBehavior) =
  ## justify items on css grid (horizontal)
  defaultGridTemplate()
  current.gridTemplate.justifyItems = con
template alignItems*(con: ConstraintBehavior) =
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
template placeItems*(con: ConstraintBehavior) =
  ## align items on css grid (vertical)
  defaultGridTemplate()
  current.gridTemplate.justifyItems = con
  current.gridTemplate.alignItems = con

template gridAutoFlow*(item: GridFlow) =
  defaultGridTemplate()
  current.gridTemplate.autoFlow = item

template gridAutoColumns*(item: Constraint) =
  defaultGridTemplate()
  current.gridTemplate.autos[dcol] = item
template gridAutoRows*(item: Constraint) =
  defaultGridTemplate()
  current.gridTemplate.autos[drow] = item

from sugar import capture

template gridTemplateDebugLines*(grid: Figuro, color: Color = blueColor) =
  ## helper that draws css grid lines. great for debugging layouts.
  rectangle "grid-debug":
    # strokeLine 3'ui, css"#0000CC"
    # draw debug lines
    boxOf grid.box
    if not grid.gridTemplate.isNil:
      computeLayout(grid, 0)
      echo "grid template post: ", grid.gridTemplate
      let cg = grid.gridTemplate.gaps[dcol]
      let wd = 1'ui
      let w = grid.gridTemplate.columns[^1].start.UICoord
      let h = grid.gridTemplate.rows[^1].start.UICoord
      echo "size: ", (w, h)
      for col in grid.gridTemplate.columns[1..^2]:
        rectangle "column", captures(col):
          fill color
          box ux(col.start.UICoord - wd), 0'ux, wd.ux(), h.ux()
      for row in grid.gridTemplate.rows[1..^2]:
        rectangle "row", captures(row):
          fill color
          box 0, row.start.UICoord - wd, w.UICoord, wd
      rectangle "edge":
        fill color.darken(0.5)
        box 0'ux, 0'ux, w, 3'ux
      rectangle "edge":
        fill color.darken(0.5)
        box 0'ux, ux(h - 3), w, 3'ux
