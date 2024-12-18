import std/options
import chroma

import ../uimaths
import ../glyphs

export uimaths, glyphs
export options, chroma

when defined(compilervm):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

type
  NodeID* = int64


type
  NodeKind* = enum
    ## Different types of nodes.
    nkFrame
    nkText
    nkRectangle
    nkDrawable
    nkScrollBar
    nkImage

  Attributes* = enum
    clipContent
    disableRender
    scrollPanel
    inactive
    preDrawReady
    postDrawReady
    contentsDrawReady
    rxWindowResize
    rootWindow
    # style attributes
    zLevelSet
    rotationSet
    fillSet
    fillHoverSet
    highlightSet
    transparencySet
    strokeSet
    imageSet
    shadowSet

  FieldSet* = enum
    ## For tracking which fields have been set by the widget user code.
    ## 
    ## An example is setting `fill` in a button's code. We want this
    ## to override any defaults the widget itself my later set.
    ## 
    ## TODO: this is hacky, but efficient
    fsZLevel
    fsRotation
    fsCornerRadius
    fsFill
    fsFillHover
    fsHighlight
    fsTransparency
    fsStroke
    fsImage
    fsShadow
    fsSetGridCols
    fsSetGridRows
    fsGridAutoFlow
    fsGridAutoRows
    fsGridAutoColumns
    fsJustifyItems
    fsAlignItems

  ShadowStyle* = enum
    ## Supports drop and inner shadows.
    DropShadow
    InnerShadow

  ZLevel* = int8

  Shadow* = object
    kind*: ShadowStyle
    blur*: UICoord
    x*: UICoord
    y*: UICoord
    color*: Color

  RenderShadow* = object
    kind*: ShadowStyle
    blur*: float32
    x*: float32
    y*: float32
    color*: Color

  Stroke* = object
    weight*: float32 # not uicoord?
    color*: Color

  ImageStyle* = object
    name*: string
    color*: Color


