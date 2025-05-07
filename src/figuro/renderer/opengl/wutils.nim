import std/strformat
import std/[options, unicode, strutils, tables, times]
import std/[os, json]

import pkg/pixie
import pkg/opengl
import pkg/windex
import pkg/chronicles

import utils
import glcommons
import ../../common/nodes/uinodes
import ../../common/rchannels

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

proc writeWindowConfig*(window: Window, winCfgFile: string) =
    try:
      let wc = WindowConfig(pos: window.pos, size: window.size)
      let jn = %*(wc)
      writeFile(winCfgFile, $(jn))
    except Defect, CatchableError:
      debug "error writing window position"

proc getWindowInfo*(window: Window): AppWindow =
    app.requestedFrame.inc

    result.minimized = window.minimized()
    result.pixelRatio = window.contentScale()

    var cwidth, cheight: cint
    let size = window.size()

    result.box.w = size.x.float32.descaled()
    result.box.h = size.y.float32.descaled()
