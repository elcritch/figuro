import chroma, common, hashes, input, internal, opengl/base,
    opengl/context, os, strformat, strutils, tables, times, typography,
    unicode,
    typography/svgfont, pixie

import patches/textboxes 
import opengl/draw

when not defined(emscripten) and not defined(fidgetNoAsync):
  import httpClient, asyncdispatch, asyncfutures, json

export input, draw

var
  windowTitle, windowUrl: string

computeTextLayout = proc(node: Node) =
  var font = fonts[node.textStyle.fontFamily]
  font.size = node.textStyle.fontSize.scaled.float32
  font.lineHeight = node.textStyle.lineHeight.scaled.float32
  if font.lineHeight == 0:
    font.lineHeight = defaultLineHeight(node.textStyle).scaled.float32
  var
    boundsMin: Vec2
    boundsMax: Vec2
    size: Vec2 = node.box.scaled.wh
  if node.textStyle.autoResize == tsWidthAndHeight:
    size.x = 0
  node.textLayout = font.typeset(
    node.text,
    pos = vec2(0, 0),
    size = size,
    hAlignMode(node.textStyle.textAlignHorizontal),
    vAlignMode(node.textStyle.textAlignVertical),
    clip = false,
    boundsMin = boundsMin,
    boundsMax = boundsMax
  )
  let bMin = boundsMin.descaled
  let bMax = boundsMin.descaled
  node.textLayoutWidth = bMax.x - bMin.x
  node.textLayoutHeight = bMax.y - bMin.y
  # echo fmt"{boundsMin=} {boundsMax=}"

proc removeExtraChildren*(node: Node) =
  ## Deal with removed nodes.
  node.nodes.setLen(node.diffIndex)

proc processHooks(parent, node: Node) =
  for child in node.nodes:
    processHooks(node, child)

proc setupFidget(
    openglVersion: (int, int),
    msaa: MSAA,
    mainLoopMode: MainLoopMode,
    pixelate: bool,
    forcePixelScale: float32,
    atlasSize: int = 1024
) =
  pixelScale = forcePixelScale

  base.start(openglVersion, msaa, mainLoopMode)
  # var thr: Thread[void]
  # createThread(thr, timerFunc)

  setWindowTitle(windowTitle)
  ctx = newContext(atlasSize = atlasSize, pixelate = pixelate, pixelScale = pixelScale)
  requestedFrame.inc

  base.drawFrame = proc() =
    # echo "\ndrawFrame"
    clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
    ctx.beginFrame(windowFrame)
    ctx.saveTransform()
    ctx.scale(ctx.pixelScale)

    mouse.cursorStyle = Default

    setupRoot()
    scrollBox.x = 0'ui
    scrollBox.y = 0'ui
    scrollBox.w = windowLogicalSize.x.descaled()
    scrollBox.h = windowLogicalSize.y.descaled()
    root.box = scrollBox

    if currTextBox != nil:
      keyboard.input = currTextBox.text
    computeEvents(root)

    drawMain()

    root.removeExtraChildren()

    computeLayout(nil, root)
    computeScreenBox(nil, root)
    processHooks(nil, root)

    # Only draw the root after everything was done:
    root.drawRoot()

    ctx.restoreTransform()
    ctx.endFrame()

    # Only set mouse style when it changes.
    if mouse.prevCursorStyle != mouse.cursorStyle:
      mouse.prevCursorStyle = mouse.cursorStyle
      echo mouse.cursorStyle
      case mouse.cursorStyle:
        of Default:
          setCursor(cursorDefault)
        of Pointer:
          setCursor(cursorPointer)
        of Grab:
          setCursor(cursorGrab)
        of NSResize:
          setCursor(cursorNSResize)

    when defined(testOneFrame):
      ## This is used for test only
      ## Take a screen shot of the first frame and exit.
      var img = takeScreenshot()
      img.writeFile("screenshot.png")
      quit()

  useDepthBuffer(false)

  if loadMain != nil:
    loadMain()

proc asyncPoll() =
  when not defined(emscripten) and
        not defined(fidgetNoAsync):
    poll(16)
    if isEvent:
      isEvent = false
      eventTimePost = epochTime()
# 
type
  MainProc* = proc () 

proc startFidget*(
    draw: proc() = nil,
    tick: proc() = nil,
    load: proc() = nil,
    setup: proc() = nil,
    fullscreen = false,
    w: Positive = 1280,
    h: Positive = 800,
    openglVersion = (3, 3),
    msaa = msaaDisabled,
    mainLoopMode: MainLoopMode = RepaintOnEvent,
    pixelate = false,
    pixelScale = 1.0
) =
  ## Starts Fidget UI library
  ## 
  common.fullscreen = fullscreen
  
  if not fullscreen:
    windowSize = vec2(uiScale * w.float32, uiScale * h.float32)
  drawMain = draw
  tickMain = tick
  loadMain = load
  let atlasStartSz = 1024 shl (uiScale.round().toInt() + 1)
  echo fmt"{atlasStartSz=}"
  
  echo "setting up new UI Event "
  uiEvent = newAsyncEvent()
  let uiEventCb =
    proc (fd: AsyncFD): bool =
      echo "UI event!"
      return true
  addEvent(uiEvent, uiEventCb)
  echo "setup new UI Event ", repr uiEvent

  setupFidget(openglVersion, msaa, mainLoopMode, pixelate, pixelScale, atlasStartSz)
  mouse.pixelScale = pixelScale

  if not setup.isNil:
    setup()

  when defined(emscripten):
    # Emscripten can't block so it will call this callback instead.
    proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}
    proc mainLoop() {.cdecl.} =
      asyncPoll()
      updateLoop()
    emscripten_set_main_loop(main_loop, 0, true)
  else:
    proc running() {.async.} =
      while base.running:
        updateLoop()
        # asyncPoll()
        if isEvent:
          isEvent = false
          eventTimePost = epochTime()
        await sleepAsync(16)
    waitFor: running()
    exit()

proc openBrowser*(url: string) =
  ## Opens a URL in a browser
  discard

proc refresh*() =
  ## Request the screen be redrawn
  requestedFrame = max(1, requestedFrame)

proc getTitle*(): string =
  ## Gets window title
  windowTitle

proc setTitle*(title: string) =
  ## Sets window title
  if (windowTitle != title):
    windowTitle = title
    setWindowTitle(title)
    refresh()

proc setWindowBounds*(min, max: Vec2) =
  base.setWindowBounds(min, max)

proc getUrl*(): string =
  windowUrl

proc setUrl*(url: string) =
  windowUrl = url
  refresh()

proc loadFontAbsolute*(name: string, pathOrUrl: string) =
  ## Loads fonts anywhere in the system.
  ## Not supported on js, emscripten, ios or android.
  if pathOrUrl.endsWith(".svg"):
    fonts[name] = readFontSvg(pathOrUrl)
  elif pathOrUrl.endsWith(".ttf"):
    fonts[name] = readFontTtf(pathOrUrl)
  elif pathOrUrl.endsWith(".otf"):
    fonts[name] = readFontOtf(pathOrUrl)
  else:
    raise newException(Exception, "Unsupported font format")

proc loadFont*(name: string, pathOrUrl: string) =
  ## Loads the font from the dataDir.
  loadFontAbsolute(name, dataDir / pathOrUrl)

proc setItem*(key, value: string) =
  ## Saves value into local storage or file.
  writeFile(&"{key}.data", value)

proc getItem*(key: string): string =
  ## Gets a value into local storage or file.
  readFile(&"{key}.data")

when not defined(emscripten) and not defined(fidgetNoAsync):
  proc httpGetCb(future: Future[string]) =
    refresh()

  proc httpGet*(url: string): HttpCall =
    if url notin httpCalls:
      result = HttpCall()
      var client = newAsyncHttpClient()
      echo "new call"
      result.future = client.getContent(url)
      result.future.addCallback(httpGetCb)
      httpCalls[url] = result
      result.status = Loading
    else:
      result = httpCalls[url]

    if result.status == Loading and result.future.finished:
      result.status = Ready
      try:
        result.data = result.future.read()
        result.json = parseJson(result.data)
      except HttpRequestError:
        echo getCurrentExceptionMsg()
        result.status = Error

    return
