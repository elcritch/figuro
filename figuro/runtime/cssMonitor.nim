import std/paths, std/os
import sigils
import sigils/threads

import ../ui/basiccss
import ../internal

import ../[shared, internal]
import ../ui/[core, events]

import libfswatch
import libfswatch/fswatch

type CssLoader* = ref object of Agent
  period*: Duration

proc cssUpdate*(tp: CssLoader, cssRules: seq[CssBlock]) {.signal.}

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var watcherSelf: WeakRef[CssLoader]

proc themeUpdate() =
  let cssRules = loadTheme()
  if cssRules.len() > 0:
    echo "CSSTheme updated: ", themePath()
    emit watcherSelf.cssUpdate(cssRules)

proc fsmonCallback(event: fsw_cevent, eventNum: cuint) =
  themeUpdate()

proc cssWatcherImpl*(self: CssLoader) =
  watcherSelf = self.unsafeWeakRef()
  let defaultTheme = themePath()
  var mon = newMonitor()
  mon.addPath(defaultTheme)
  mon.setCallback(fsmonCallback)
  mon.start()

proc cssLoaderImpl*(self: CssLoader) =
  echo "css start"
  while true:
    echo "CSSTheme check"
    let cssRules = loadTheme()
    if cssRules.len() > 0:
      echo "CSSTheme updated: ", themePath()
      emit self.cssUpdate(cssRules)
    os.sleep(30_000)

proc cssLoader*(self: CssLoader) {.slot.} =
  echo "Starting CSS Loader"
  cssLoaderImpl(self)

proc cssWatcher*(self: CssLoader) {.slot.} =
  echo "Starting CSS Watcher"
  cssWatcherImpl(self)
