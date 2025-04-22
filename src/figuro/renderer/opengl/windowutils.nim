import pkg/[pixie, chroma]
import pkg/sigils/weakrefs
import pkg/chronicles
import std/[strformat, strutils, os, files, json]
import ../../common/nodes/uinodes

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

proc writeWindowConfig*(window: WindowConfig, winCfgFile: string) =
    try:
      let jn = %*(window)
      writeFile(winCfgFile, $(jn))
    except Defect, CatchableError:
      debug "error writing window position"
