import std/options
import chroma

import ../uimaths
import ../fonttypes

export uimaths, fonttypes
export options, chroma

when defined(compilervm):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

type NodeID* = int64

type
  Directions* = enum
    dTop
    dRight
    dBottom
    dLeft

  DirectionCorners* = enum
    dcTopLeft
    dcTopRight
    dcBottomRight
    dcBottomLeft

  NodeKind* = enum
    ## Different types of nodes.
    nkFrame
    nkText
    nkRectangle
    nkDrawable
    nkScrollBar
    nkImage

  NodeFlags* = enum
    NfClipContent
    NfDisableRender
    NfScrollPanel
    NfDead
    NfPreDrawReady
    NfPostDrawReady
    NfContentsDrawReady
    NfRootWindow
    NfInitialized
    NfSkipLayout
    NfInactive

  Attributes* = enum ## user facing attributes
    SkipCss ## Skip applying CSS to this node
    Hidden ## Hidden from layout and rendering
    Disabled ## Disabled from user interaction
    Active ## Active from user interaction
    Checked ## Checked from user interaction
    Open ## Open from user interaction
    Selected ## Selected from user interaction
    Hover ## Hovered from user interaction
    Focusable ## Focusable from user interaction
    Focus ## Focused from user interaction
    FocusVisible ## Focus visible from user interaction
    FocusWithin ## Focus within from user interaction


  FieldSetAttrs* = enum
    ## For tracking which fields have been set by the widget user code.
    ## 
    ## An example is setting `fill` in a button's code. We want this
    ## to override any defaults the widget itself my later set.
    ## 
    ## ~~TODO: this is hacky, but efficient~~
    ## TODO: remove these...
    fsZLevel
    fsRotation
    fsCornerRadius
    fsClipContent
    fsFill
    fsFillHover
    fsHighlight
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
    blur*: UiScalar
    spread*: UiScalar
    x*: UiScalar
    y*: UiScalar
    color*: Color

  RenderShadow* = object
    blur*: float32
    spread*: float32
    x*: float32
    y*: float32
    color*: Color

  Stroke* = object
    weight*: float32 # not uicoord?
    color*: Color

  ImageId* = distinct Hash

  ImageStyle* = object
    name*: string
    color*: Color
    id*: ImageId

proc `==`*(a, b: ImageId): bool {.borrow.}
