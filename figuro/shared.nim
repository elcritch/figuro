import std/[sequtils, tables, hashes]
import std/[options, unicode, strformat]
import pkg/[variant]

import common/[extras, uimaths]
import inputs
from os import `/`

export sequtils, strformat, tables, hashes
export variant
export extras, uimaths
export inputs
export `/`

import chroma

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

const
  clearColor* = color(0, 0, 0, 0)
  whiteColor* = color(1, 1, 1, 1)
  blackColor* = color(0, 0, 0, 1)

const
  DataDirPath* {.strdefine.} = "./data"

type
  AppStatePartial* = tuple[tickCount, requestedFrame: int, uiScale: float32]

  AppState* = object
    running*, focused*, minimized*, fullscreen*: bool

    width*, height*: int
    # UI Scale
    uiScale*: float32
    autoUiScale*: bool

    requestedFrame*: int
    frameCount*: int
    tickCount*: int

    windowSize*: Position ## Screen size in logical coordinates.
    windowRawSize*: Vec2    ## Screen coordinates
    # windowFrame*: Vec2   ## Pixel coordinates

    pixelate*: bool ## ???
    pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels
    pixelScale*: float32 ## Pixel multiplier user wants on the UI

    lastDraw*, lastTick*: int

var
  dataDir* {.runtimeVar.}: string = DataDirPath
  app* {.runtimeVar.} = AppState(
    uiScale: 1.0,
    autoUiScale: true
  )


type
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


template dispatchEvent*(evt: typed) =
  result.add(evt)

