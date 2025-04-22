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
  AppFrame*[T] = ref object of Agent
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
    DecoratedResizable, DecoratedFixedSized, Undecorated, Transparent

proc windowCfgFile*(frame: WeakRef[AppFrame]): string = 
  frame[].configFile & ".window"

proc loadLastWindow*(frame: WeakRef[AppFrame]): WindowConfig =
  result = WindowConfig()
  if frame.windowCfgFile().fileExists():
    try:
      let jn = parseFile(frame.windowCfgFile())
      result = jn.to(WindowConfig)
    except Defect, CatchableError:
      discard
  notice "loadLastWindow", config= result

proc writeWindowConfig*(window: WindowConfig, winCfgFile: string) =
    try:
      let jn = %*(window)
      writeFile(winCfgFile, $(jn))
    except Defect, CatchableError:
      debug "error writing window position"
