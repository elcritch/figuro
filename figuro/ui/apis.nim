import chroma, bumpy
import std/[algorithm, macros, tables, os]
# import cssgrid

import std/[hashes]

import commons, core

export core

proc defaultLineHeight*(fontSize: UICoord): UICoord =
  result = fontSize * defaultlineHeightRatio
proc defaultLineHeight*(ts: TextStyle): UICoord =
  result = defaultLineHeight(ts.fontSize)

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

proc boxFrom*(x, y, w, h: float32) =
  ## Sets the box dimensions.
  current.box = initBox(x, y, w, h)

template frame*(id: static string, inner: untyped): untyped =
  ## Starts a new frame.
  node(nkFrame, id, inner):
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

template rectangle*(id, inner: untyped): untyped =
  ## Starts a new rectangle.
  node(nkRectangle, id, inner)

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

proc clearInputs*() =
  resetNodes = 0
  uxInputs.mouse.pos = Position(vec2(0, 0))
  uxInputs.mouse.wheelDelta = Position(vec2(0, 0))
  uxInputs.mouse.consumed = false
  uxInputs.mouse.clickedOutside = false

## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##             Node User Interactions
## ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
## 
## These APIs provide the basic functionality for
## interacting with user interactions. 
## 

type CSSConstraint = distinct int # move to cssgrid

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
  x: int|float32|float64|UICoord|CSSConstraint,
  y: int|float32|float64|UICoord|CSSConstraint,
  w: int|float32|float64|UICoord|CSSConstraint,
  h: int|float32|float64|UICoord|CSSConstraint
) =
  ## Sets the box dimensions with integers
  ## Always set box before orgBox when doing constraints.
  boxFrom(fltOrZero x, fltOrZero y, fltOrZero w, fltOrZero h)
  # current.cxOffset = [csOrFixed(x), csOrFixed(y)]
  # current.cxSize = [csOrFixed(w), csOrFixed(h)]
  # orgBox(float32 x, float32 y, float32 w, float32 h)

proc box*(rect: Box) =
  ## Sets the box dimensions with integers
  box(rect.x, rect.y, rect.w, rect.h)

proc size*(
  w: int|float32|float64|UICoord|CSSConstraint,
  h: int|float32|float64|UICoord|CSSConstraint,
) =
  ## Sets the box dimension width and height
  when w is CSSConstraint:
    current.cxSize[dcol] = w
  else:
    current.cxSize[dcol] = csFixed(w.UiScalar)
    current.box.w = w.UICoord
  
  when h is CSSConstraint:
    current.cxSize[drow] = h
  else:
    current.cxSize[drow] = csFixed(h.UiScalar)
    current.box.h = h.UICoord

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

proc clipContent*(clip: bool) =
  ## Causes the parent to clip the children.
  if clip:
    current.attrs.incl clipContent
  else:
    current.attrs.excl clipContent


proc fill*(color: Color) =
  ## Sets background color.
  current.fill = color

proc fill*(color: Color, alpha: float32) =
  ## Sets background color.
  current.fill = color
  current.fill.a = alpha

proc fill*(color: string, alpha: float32 = 1.0) =
  ## Sets background color.
  current.fill = parseHtmlColor(color)
  current.fill.a = alpha

proc fill*(node: Figuro) =
  ## Sets background color.
  current.fill = node.fill

# template callHover*(inner: untyped) =
#   ## Code in the block will run when this box is hovered.
#   proc doHover(obj: Figuro) {.slot.} =
#     echo "hi"
#     `inner`
#   root.connect(eventHover, current, doHover)

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