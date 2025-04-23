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

proc cssUpdate*(tp: CssLoader, path: string, css: CssTheme) {.signal.}

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var lastModificationTime: Table[string, Time]

proc themePath*(): string =
  result = "theme.css".absolutePath()

proc appThemePath*(): string =
  result = os.getAppFilename().replace(".exe", "") & ".css"

proc loadTheme*(theme: string = themePath()): CssTheme =
  if theme.fileExists():
    let ts = getLastModificationTime(theme)
    if theme notin lastModificationTime or ts > lastModificationTime[theme]:
      lastModificationTime[theme] = ts
      notice "Loading CSS file", cssFile = theme
      let parser = newCssParser(Path(theme))
      result = newCssTheme(parser)
      notice "Loaded CSS file", cssFile = theme

proc updateTheme*(self: AppFrame, path: string, css: CssTheme) {.slot.} =
  if css != nil:
    debug "CSS theme into app", numberOfCssRules = rules(css).toSeq().len()
    var idx = -1
    for i, (path, theme) in self.theme.css:
      if path == path:
        idx = i; break
    if idx == -1:
      self.theme.css.add((path, css))
      idx = self.theme.css.len - 1
    else:
      let values = self.theme.css[idx].theme.values
      self.theme.css[idx] = (path, css)
      self.theme.css[idx].theme.values = values
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

    var appFile = appThemePath()
    let watchId2: WatchId = watch(appFile.splitFile.dir, watchCallback, {}, nil)
    notice "Started CSS Watcher", theme = defaultTheme, appTheme= appFile

    proc update(file: string) =
      let css = loadTheme(file)
      if css != nil:
        notice "CSS Updated: ", file = file, css = rules(css).toSeq.len()
        emit self.cssUpdate(css)
        os.sleep(16) # TODO: fixme: this is a hack to ensure proper text resizing 
        notice "CSS Updated: second: ", file = file, css = rules(css).toSeq.len()
        emit self.cssUpdate(css)

    let cssFiles = @[appFile, defaultTheme]
    var currTheme = ""
    for file in cssFiles:
      if file.existsFile():
        currTheme = file

    if currTheme.fileExists():
      currTheme.update()

    while isRunning(getCurrentSigilThread()[]):
      let file = cssUpdates.recv()
      if file != currTheme:
        notice "CSS Skipping", file = file
        continue
      else:
        file.update()
