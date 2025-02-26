import std/paths, std/os
import pkg/threading/channels
import sigils
import sigils/threads

import ../../commons
import ../../ui/core

when not defined(noFiguroDmonMonitor):
  import dmon

import pkg/chronicles

type CssLoader* = ref object of Agent
  period*: Duration

proc cssUpdate*(tp: CssLoader, cssRules: seq[CssBlock]) {.signal.}

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

when not defined(noFiguroDmonMonitor):
  var watcherSelf: WeakRef[CssLoader]
  var cssUpdates = newChan[string](10)

  proc watchCallback(
      watchId: WatchId,
      action: DmonAction,
      rootDir, filepath, oldfilepath: string,
      userData: pointer,
  ) {.gcsafe.} =
    {.cast(gcsafe).}:
      let file = rootDir / filepath
      let res = cssUpdates.trySend(file)
      info "THEME watcher callback", rootDir = rootDir, filePath = filepath, sendRes = res


  proc cssWatcher*(self: CssLoader) {.slot.} =
    notice "Starting CSS Watcher"
    initDmon()
    startDmonThread()

    let defaultTheme = themePath()
    let watchId1: WatchId = watch(defaultTheme.splitFile.dir, watchCallback, {}, nil)

    var appFile = os.getAppFilename().replace(".exe", "") & ".css"
    let watchId2: WatchId = watch(appFile.splitFile.dir, watchCallback, {}, nil)
    notice "Started CSS Watcher", theme = themePath(), appTheme= appFile

    proc updateTheme(file: string) =
      notice "CSS Updated: ", file = file
      let cssRules = loadTheme(file)
      emit self.cssUpdate(cssRules)
      os.sleep(16) # TODO: fixme: this is a hack to ensure proper text resizing 
      emit self.cssUpdate(cssRules)

    let cssFiles = @[defaultTheme, appFile]
    var currTheme = ""
    for file in cssFiles:
      if file.existsFile():
        currTheme = file

    if currTheme.fileExists():
      currTheme.updateTheme()

    while true:
      let file = cssUpdates.recv()
      if file notin cssFiles:
        notice "CSS Skipping", file = file
        continue
      else:
        file.updateTheme()
