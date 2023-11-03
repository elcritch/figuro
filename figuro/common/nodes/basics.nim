import std/[options, unicode]
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
    # style attributes
    # todo: this is hacky, but efficient
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

  FidgetConstraint* = enum
    cMin
    cMax
    cScale
    cStretch
    cCenter

  HAlign* = enum
    hLeft
    hCenter
    hRight

  VAlign* = enum
    vTop
    vCenter
    vBottom

  TextAutoResize* = enum
    ## Should text element resize and how.
    tsNone
    tsWidthAndHeight
    tsHeight

  BorderStyle* = object
    ## What kind of border.
    # color*: Color
    width*: float32

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


