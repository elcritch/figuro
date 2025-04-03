import std/[sequtils, tables, hashes]
import std/[options, unicode, strformat]
import std/paths
import std/os
import pkg/variant
export paths, sequtils, strformat, tables, hashes
export variant

import extras, uimaths, inputs
export extras, uimaths, inputs

import pkg/chroma

type FiguroError* = object of CatchableError

type
  AppMainThreadEff* = object of RootEffect ## MainThr effect
  RenderThreadEff* = object of RootEffect ## RenderThr effect

{.push hint[Name]: off.}
proc AppMainThread*() {.tags: [AppMainThreadEff].} =
  discard

proc RenderThread*() {.tags: [RenderThreadEff].} =
  discard

template threadEffects*(arg: typed) =
  arg()

{.pop.}

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

const
  clearColor* = color(0, 0, 0, 0)
  whiteColor* = color(1, 1, 1, 1)
  blackColor* = color(0, 0, 0, 1)
  blueColor* = color(0, 0, 1, 1)

const DataDirPath* {.strdefine.} =
  Path(currentSourcePath()).splitPath().head / Path(".." / ".." / "data")

type ScaleInfo* = object
  x*: float32
  y*: float32

type
  AppStatePartial* = tuple[requestedFrame: int, uiScale: float32]

  AppState* = object
    running*: bool
    requestedFrame*: int = 2
    lastDraw*, lastTick*: int

    # UI Scale
    uiScale*: float32
    autoUiScale*: bool
    pixelScale*: float32 ## Pixel multiplier user wants on the UI

var
  dataDir* {.runtimeVar.}: string = DataDirPath.string
  app* {.runtimeVar.} = AppState(running: true, uiScale: 1.0, autoUiScale: true)

type
  # Events* = GenericEvents[void]
  Events*[T] = object
    data*: TableRef[TypeId, Variant]

proc scaled*(a: Box): Rect =
  toRect(a * app.uiScale.UiScalar)

proc descaled*(a: Rect): Box =
  let a = a / app.uiScale
  result.x = a.x.UiScalar
  result.y = a.y.UiScalar
  result.w = a.w.UiScalar
  result.h = a.h.UiScalar

proc scaled*(a: Position): Vec2 =
  toVec(a * app.uiScale.UiScalar)

proc scaled*(a: UiSize): Vec2 =
  toVec(a * app.uiScale.UiScalar)

proc descaled*(a: Vec2): Position =
  let a = a / app.uiScale
  result.x = a.x.UiScalar
  result.y = a.y.UiScalar

proc scaled*(a: UiScalar): float32 =
  a.float32 * app.uiScale

proc descaled*(a: float32): UiScalar =
  UiScalar(a / app.uiScale)

template dispatchEvent*(evt: typed) =
  result.add(evt)
