import std/paths, std/os
import sigils
import sigils/threads

import ../../commons
import ../../common/rchannels
import ../../ui/core

when not defined(noFiguroDmonMonitor):
  import dmon

import pkg/chronicles

type CssLoader* = ref object of Agent
  period*: Duration

proc cssUpdate*(tp: CssLoader, css: CssTheme) {.signal.}

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var lastModificationTime: times.Time

proc themePath*(): string =
  result = "theme.css".absolutePath()

proc loadTheme*(defaultTheme: string = themePath()): CssTheme =
  # let defaultTheme = themePath()
  if defaultTheme.fileExists():
    let ts = getLastModificationTime(defaultTheme)
    if ts > lastModificationTime:
      lastModificationTime = ts
      notice "Loading CSS file", cssFile = defaultTheme
      let parser = newCssParser(Path(defaultTheme))
      result = newCssTheme(parser)
      notice "Loaded CSS file", cssFile = defaultTheme

proc updateTheme*(self: AppFrame, css: CssTheme) {.slot.} =
  debug "CSS theme into app", numberOfCssRules = rules(css).toSeq().len()
  let values = self.theme.css.values
  self.theme.css = css
  self.theme.css.values = values
  refresh(self.root)

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

    proc update(file: string) =
      let css = loadTheme(file)
      if css != nil:
        notice "CSS Updated: ", file = file, css = rules(css).toSeq.len()
        emit self.cssUpdate(css)
        os.sleep(16) # TODO: fixme: this is a hack to ensure proper text resizing 
        notice "CSS Updated: second: ", file = file, css = rules(css).toSeq.len()
        emit self.cssUpdate(css)

    let cssFiles = @[defaultTheme, appFile]
    var currTheme = ""
    for file in cssFiles:
      if file.existsFile():
        currTheme = file

    if currTheme.fileExists():
      currTheme.update()

    while true:
      let file = cssUpdates.recv()
      if file notin cssFiles:
        notice "CSS Skipping", file = file
        continue
      else:
        file.update()
