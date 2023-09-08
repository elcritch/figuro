import chroma, bumpy
import std/[algorithm, macros, tables, os]
import cssgrid

import std/[hashes]

import commons, core

export core, cssgrid


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


# when not defined(js):
#   func hAlignMode*(align: HAlign): HAlignMode =
#     case align:
#       of hLeft: HAlignMode.Left
#       of hCenter: Center
#       of hRight: HAlignMode.Right

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
  x: int|float32|float64|UICoord|CSSConstraint,
  y: int|float32|float64|UICoord|CSSConstraint,
  w: int|float32|float64|UICoord|CSSConstraint,
  h: int|float32|float64|UICoord|CSSConstraint
) =
  ## Sets the box dimensions with integers
  ## Always set box before orgBox when doing constraints.
  boxFrom(fltOrZero x, fltOrZero y, fltOrZero w, fltOrZero h)
  current.cxOffset = [csOrFixed(x), csOrFixed(y)]
  current.cxSize = [csOrFixed(w), csOrFixed(h)]

template box*(rect: Box) =
  ## Sets the box dimensions with integers
  box(rect.x, rect.y, rect.w, rect.h)

template size*(
  w: int|float32|float64|UICoord,
  h: int|float32|float64|UICoord,
) =
  ## Sets the box dimension width and height
  current.cxSize[dcol] = csFixed(w.UiScalar)
  current.box.w = w.UICoord
  
  current.cxSize[drow] = csFixed(h.UiScalar)
  current.box.h = h.UICoord

template size*(
  w: CSSConstraint,
  h: CSSConstraint,
) =
  ## Sets the box dimension width and height
  current.cxSize[dcol] = w
  current.cxSize[drow] = h

template boxOf*(node: Figuro) =
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`
  current.box = node.box

template boxSizeOf*(node: Figuro) =
  ## Sets current node's box from another node
  ## e.g. `boxOf(parent)`
  current.box = node.box.atXY(0, 0)

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

template clipContent*(clip: bool) =
  ## Causes the parent to clip the children.
  if clip:
    current.attrs.incl clipContent
  else:
    current.attrs.excl clipContent


template fill*(color: Color) =
  ## Sets background color.
  current.fill = color

template fill*(color: Color, alpha: float32) =
  ## Sets background color.
  current.fill = color
  current.fill.a = alpha

template fill*(color: string, alpha: float32 = 1.0) =
  ## Sets background color.
  current.fill = parseHtmlColor(color)
  current.fill.a = alpha

template fill*(node: Figuro) =
  ## Sets background color.
  current.fill = node.fill

# template callHover*(inner: untyped) =
#   ## Code in the block will run when this box is hovered.
#   proc doHover(obj: Figuro) {.slot.} =
#     echo "hi"
#     `inner`
#   root.connect(onHover, current, doHover)

template onHover*(inner: untyped) =
  ## Code in the block will run when this box is hovered.
  current.listens.mouse.incl(evHover)
  if evHover in current.events.mouse:
    inner

template onClick*(inner: untyped) =
  ## On click event handler.
  current.listens.mouse.incl(evClick)
  if evClick in current.events.mouse and
      MouseLeft in uxInputs.buttonPress:
    inner

template onClickOut*(inner: untyped) =
  ## On click event handler.
  current.listens.mouse.incl(evClickOut)
  if evClickOut in current.events.mouse and
      MouseLeft in uxInputs.buttonPress:
    inner

template cornerRadius*(radius: UICoord) =
  ## Sets all radius of all 4 corners.
  current.cornerRadius = UICoord radius

template cornerRadius*(radius: float|float32) =
  cornerRadius(UICoord radius)

proc loadTypeFace*(name: string): TypefaceId =
  ## Sets all radius of all 4 corners.
  internal.getTypeface(name)

proc loadFont*(font: GlyphFont): FontId =
  ## Sets all radius of all 4 corners.
  internal.getFont(font)

template setText*(font: FontId, text: string) =
  current.textLayout = internal.getTypeset(text, font, current.box)


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

{.hint[Name]:off.}

proc findRoot*(node: Figuro): Figuro =
  result = node
  while result.parent != nil:
    result = node.parent
  echo "findRoot: ", result.getId, " box: ", result.box

template Vw*(size: float32): UICoord =
  ## percentage of Viewport width
  current.attrs.incl rxWindowResize
  app.windowSize.x * size.UICoord / 100.0

template Vh*(size: float32): UICoord =
  ## percentage of Viewport height
  current.attrs.incl rxWindowResize
  app.windowSize.y * size.UICoord / 100.0

template `'vw`*(n: string): UICoord =
  ## numeric literal view width unit
  Vw(parseFloat(n))

template `'vh`*(n: string): UICoord =
  ## numeric literal view height unit
  Vh(parseFloat(n))

template WPerc*(n: SomeNumber): UICoord =
  ## numeric literal percent of parent width
  UICoord(max(0'f32, current.parent.box.w.float32 * n.float32 / 100.0))

template HPerc*(n: SomeNumber): UICoord =
  ## numeric literal percent of parent height
  UICoord(max(0'f32, current.parent.box.h.float32 * n.float32 / 100.0))

template `'pw`*(n: string): UICoord =
  ## numeric literal view width unit
  WPerc(parseFloat(n))

template `'ph`*(n: string): UICoord =
  ## numeric literal view height unit
  HPerc(parseFloat(n))

proc csFixed*(coord: UICoord): Constraint =
  csFixed(coord.UiScalar)

{.hint[Name]:on.}

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node Layouts and Constraints
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## setting up layouts and constraingts. 
## 

template gridTemplateColumns*(args: untyped) =
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

template gridTemplateRows*(args: untyped) =
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
template justifyContent*(con: ConstraintBehavior) =
  ## justify items on css grid (horizontal)
  defaultGridTemplate()
  current.gridTemplate.justifyContent = con
template alignContent*(con: ConstraintBehavior) =
  ## align items on css grid (vertical)
  defaultGridTemplate()
  current.gridTemplate.alignContent = con
template placeItems*(con: ConstraintBehavior) =
  ## align items on css grid (vertical)
  defaultGridTemplate()
  current.gridTemplate.justifyItems = con
  current.gridTemplate.alignItems = con

template gridAutoColumns*(item: Constraint) =
  defaultGridTemplate()
  current.gridTemplate.autos[dcol] = item
template gridAutoRows*(item: Constraint) =
  defaultGridTemplate()
  current.gridTemplate.autos[drow] = item

from sugar import capture

template gridTemplateDebugLines*(draw: bool, color: Color = blackColor) =
  ## helper that draws css grid lines. great for debugging layouts.
  if draw:
    # draw debug lines
    if not current.gridTemplate.isNil:
      # computeLayout(nil, current)
      # echo "grid template post: ", repr current.gridTemplate
      let cg = current.gridTemplate.gaps[dcol]
      let wd = max(10, cg.UICoord)
      let w = current.gridTemplate.columns[^1].start
      let h = current.gridTemplate.rows[^1].start
      # echo "size: ", (w, h)
      for col in current.gridTemplate.columns[1..^2]:
        capture col:
          rectangle "column":
            # layoutAlign laIgnore
            fill color
            box col.start.UICoord - wd, 0.UICoord, wd, h.UICoord
      for row in current.gridTemplate.rows[1..^2]:
        capture row:
          rectangle "row":
            # layoutAlign laIgnore
            fill color
            box 0, row.start.UICoord - wd, w.UICoord, wd

