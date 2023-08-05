import std/[sequtils, tables, json, hashes]
import std/[options, unicode, strformat]
import pkg/[variant, chroma, cssgrid, windy]

import common/[extras, uimaths]
import inputs

export sequtils, strformat, tables, hashes
export variant
export extras, uimaths
export inputs

import pretty

when defined(js):
  import dom2, html/ajax
else:
  import typography, asyncfutures

const
  clearColor* = color(0, 0, 0, 0)
  whiteColor* = color(1, 1, 1, 1)
  blackColor* = color(0, 0, 0, 1)

const
  DataDirPath* {.strdefine.} = "data"

type
  AppState* = object
    running*, focused*, minimized*, fullscreen*: bool

var
  # UI Scale
  uiScale*: float32 = 1.0
  autoUiScale*: bool = true
  requestedFrame*: int

  windowLogicalSize*: Vec2 ## Screen size in logical coordinates.
  windowSize*: Vec2    ## Screen coordinates
  # windowFrame*: Vec2   ## Pixel coordinates
  pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels
  pixelScale*: float32 ## Pixel multiplier user wants on the UI

  mouse* = Mouse()
  keyboard* = Keyboard()

  dataDir*: string = DataDirPath

  app*: AppState


type
  All* = distinct object
  # Events* = GenericEvents[void]
  Events*[T] = object
    data*: TableRef[TypeId, Variant]

when not defined(js):
  var
    # currTextBox*: TextBox[Node]
    fonts*: Table[string, Font]

template scaled*(a: Box): Rect = Rect(a * common.uiScale.UICoord)
template descaled*(a: Rect): Box = Box(a / common.uiScale)

template scaled*(a: Position): Vec2 = Vec2(a * common.uiScale.UICoord)
template descaled*(a: Vec2): Position = Position(a / common.uiScale)

template scaled*(a: UICoord): float32 =
  a.float32 * common.uiScale
template descaled*(a: float32): UICoord =
  UICoord(a / common.uiScale)

proc x*(mouse: Mouse): UICoord = mouse.pos.descaled.x
proc y*(mouse: Mouse): UICoord = mouse.pos.descaled.x

proc emptyFuture*(): Future[void] =
  result = newFuture[void]()
  result.complete()

const
  MouseButtons* = [
    MouseLeft,
    MouseRight,
    MouseMiddle,
    MouseButton4,
    MouseButton5
  ]

proc setMousePos*(item: var Mouse, x, y: float64) =
  item.pos = vec2(x, y)
  item.pos *= pixelRatio / item.pixelScale
  item.delta = item.pos - item.prevPos
  item.prevPos = item.pos


template dispatchEvent*(evt: typed) =
  result.add(evt)

