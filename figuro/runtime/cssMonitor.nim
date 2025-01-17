import std/paths, std/os
import sigils
import sigils/threads

import ../ui/basiccss

import ../shared
import ../ui/[core]

import libfswatch
import libfswatch/fswatch

import pkg/chronicles

type CssLoader* = ref object of Agent
  period*: Duration

proc cssUpdate*(tp: CssLoader, cssRules: seq[CssBlock]) {.signal.}

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var watcherSelf: WeakRef[CssLoader]

proc fsmonCallback(event: fsw_cevent, eventNum: cuint) =
  let cssRules = loadTheme()
  emit watcherSelf.cssUpdate(cssRules)
  os.sleep(16) # TODO: fixme: this is a hack to ensure proper text resizing 
  emit watcherSelf.cssUpdate(cssRules)

proc cssLoader*(self: CssLoader) {.slot.} =
  notice "Starting CSS Loader"
  while true:
    let cssRules = loadTheme()
    emit self.cssUpdate(cssRules)
    os.sleep(16) # TODO: fixme: this is a hack to ensure proper text resizing 
    emit self.cssUpdate(cssRules)
    os.sleep(300_000)

proc cssWatcher*(self: CssLoader) {.slot.} =
  notice "Starting CSS Watcher"
  watcherSelf = self.unsafeWeakRef()
  let defaultTheme = themePath()
  var mon = newMonitor()
  mon.addPath(defaultTheme)
  mon.setCallback(fsmonCallback)
  mon.start()
