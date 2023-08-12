import std/[sequtils, tables, hashes]
import std/[options, unicode, strformat]
import pkg/[variant]

import common/[extras, uimaths]
import inputs

export sequtils, strformat, tables, hashes
export variant
export extras, uimaths
export inputs

when defined(js):
  import dom2, html/ajax
else:
  import chroma

const
  clearColor* = color(0, 0, 0, 0)
  whiteColor* = color(1, 1, 1, 1)
  blackColor* = color(0, 0, 0, 1)

const
  DataDirPath* {.strdefine.} = "data"

type
  AppState* = object
    running*, focused*, minimized*, fullscreen*: bool

    # UI Scale
    uiScale*: float32
    autoUiScale*: bool

    requestedFrame*: int
    frameCount*, tickCount*: uint

    windowLogicalSize*: Vec2 ## Screen size in logical coordinates.
    windowSize*: Vec2    ## Screen coordinates
    # windowFrame*: Vec2   ## Pixel coordinates
    pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels
    pixelScale*: float32 ## Pixel multiplier user wants on the UI

    lastDraw*, lastTick*: int64

  AppInputs* = object
    mouse*: Mouse
    keyboard*: Keyboard

var
  dataDir*: string = DataDirPath
  app* = AppState(
    uiScale: 1.0,
    autoUiScale: true
  )
  uiinputs* = AppInputs(mouse: Mouse(), keyboard: Keyboard())


type
  All* = distinct object
  # Events* = GenericEvents[void]
  Events*[T] = object
    data*: TableRef[TypeId, Variant]


template scaled*(a: Box): Rect = Rect(a * app.uiScale.UICoord)
template descaled*(a: Rect): Box = Box(a / app.uiScale)

template scaled*(a: Position): Vec2 = Vec2(a * app.uiScale.UICoord)
template descaled*(a: Vec2): Position = Position(a / app.uiScale)

template scaled*(a: UICoord): float32 =
  a.float32 * app.uiScale
template descaled*(a: float32): UICoord =
  UICoord(a / app.uiScale)

proc x*(mouse: Mouse): UICoord = mouse.pos.descaled.x
proc y*(mouse: Mouse): UICoord = mouse.pos.descaled.x

proc setMousePos*(item: var Mouse, x, y: float64) =
  item.pos = vec2(x, y)
  item.pos *= app.pixelRatio / item.pixelScale
  item.delta = item.pos - item.prevPos
  item.prevPos = item.pos


template dispatchEvent*(evt: typed) =
  result.add(evt)

