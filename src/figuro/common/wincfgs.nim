import std/strformat
import std/[options, unicode, strutils, tables, times]
import std/[os, json]

import pkg/pixie
import pkg/opengl
import pkg/windex
import pkg/chronicles

import nodes/uinodes
import rchannels

type
  WindowConfig* = object
    pos*: IVec2 = ivec2(100, 100)
    size*: IVec2 = ivec2(0, 0)

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

proc writeWindowConfig*(wcfg: WindowConfig, winCfgFile: string) =
    try:
      let jn = %*(wcfg)
      writeFile(winCfgFile, $(jn))
    except Defect, CatchableError:
      debug "error writing window position"
