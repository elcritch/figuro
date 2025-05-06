import std/paths, std/os
import sigils
import sigils/threads

import ../../commons
import ../../common/rchannels
import ../../ui/core
import ../../ui/cssengine
when not defined(noFiguroDmonMonitor):
  import dmon

import pkg/chronicles

type CssLoader* = ref object of Agent
  period*: Duration

proc cssUpdate*(tp: CssLoader, path: string) {.signal.}

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

proc themePath*(): string =
  result = "theme.css".absolutePath()

proc appThemePath*(): string =
  result = os.getAppFilename().replace(".exe", "") & ".css"

proc loadTheme*(theme: string = themePath(), values: CssValues): CssTheme =
  if theme.fileExists():
    notice "Loading CSS file", cssFile = theme
    let parser = newCssParser(Path(theme))
    result = newCssTheme(parser, values)
    notice "Loaded CSS file", cssFile = theme

proc updateTheme*(self: AppFrame, path: string) {.slot.} =
  let css = loadTheme(path, self.theme.cssValues)
  if css != nil:
    debug "before update CSS theme into app", path = path, numberOfCssRules = rules(css).toSeq().len(), cssPaths = self.theme.css.mapIt(it[0])
    var idx = -1
    for i, css in self.theme.css:
      if path == css[0]:
        idx = i; break
    if idx == -1:
      self.theme.css.add((path, css))
      idx = self.theme.css.len - 1
      debug "Adding new CSS theme into app", path = path, idx = idx
    else:
      debug "Updating CSS theme into app", path = path, idx = idx
      self.theme.css[idx] = (path, css)
    debug "CSS theme into app", path = path, numberOfCssRules = rules(css).toSeq().len(), cssPaths = self.theme.css.mapIt(it[0])
    applyThemeRoots(self.root)
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
      notice "CSS Updated: ", file = file
      emit self.cssUpdate(file)
      os.sleep(16) # TODO: fixme: this is a hack to ensure proper text resizing 
      notice "CSS Updated: second: ", file = file
      emit self.cssUpdate(file)

    let cssFiles = @[appFile, defaultTheme]
    var currTheme = ""
    for file in cssFiles:
      if file.existsFile():
        currTheme = file

    if currTheme.fileExists():
      currTheme.update()

    while isRunning(getCurrentSigilThread()[]):
      let file = cssUpdates.recv()
      file.update()
