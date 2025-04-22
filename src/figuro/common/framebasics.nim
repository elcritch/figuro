import std/[strformat, strutils, os, files, json]
import pkg/[bumpy]
import pkg/[pixie, chroma]
import pkg/sigils
import pkg/chronicles

import nodes/cssparser
import fonttypes
import rchannels
import inputs
import uimaths

type
  AppFrameImpl*[T] = ref object of Agent
    frameRunner*: AgentProcTy[tuple[]]
    proxies*: seq[AgentProxyShared]
    redrawNodes*: OrderedSet[T]
    redrawLayout*: OrderedSet[T]
    root*: T
    uxInputList*: RChan[AppInputs]
    rendInputList*: RChan[RenderCommands]
    appWindow*: AppWindow
    windowTitle*: string
    windowStyle*: FrameStyle
    theme*: Theme
    configFile*: string

  Theme* = object
    font*: UiFont
    css*: CssTheme

  FrameStyle* {.pure.} = enum
    FrameResizable, FrameFixedSized, FrameUndecorated, FrameTransparent

proc frameCfgFile*[T](frame: WeakRef[AppFrameImpl[T]]): string = 
  frame[].configFile & ".frame"

proc loadLastWindow*[T](frame: WeakRef[AppFrameImpl[T]]): FrameConfig =
  result = FrameConfig()
  if frameCfgFile(frame).fileExists():
    try:
      let jn = parseFile(frameCfgFile(frame))
      result = jn.to(FrameConfig)
    except Defect, CatchableError:
      discard
  notice "loadLastWindow", config= result

proc writeFrameConfig*(cfg: FrameConfig, winCfgFile: string) =
    try:
      let jn = %*(cfg)
      writeFile(winCfgFile, $(jn))
    except Defect, CatchableError:
      debug "error writing window position"
