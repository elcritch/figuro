import std/hashes

import pkg/windy
import pkg/opengl
import pkg/boxy

import ../shared
import ./default/renderer

export shared
export render, Renderer

proc getScaleInfo*(window: Window): ScaleInfo =
  let scale = window.contentScale()
  result.x = scale
  result.y = scale

proc updateWindowSize*(window: Window) =
  app.requestedFrame.inc

  let size = window.size()
  app.windowRawSize.x = size.x.toFloat
  app.windowRawSize.y = size.y.toFloat

  app.minimized = window.minimized()
  app.pixelRatio = window.contentScale()

  let scale = window.getScaleInfo()
  if app.autoUiScale:
    app.uiScale = min(scale.x, scale.y)

  let sz = app.windowRawSize.descaled()
  # TODO: set screen logical offset too?
  app.windowSize.w = sz.x
  app.windowSize.h = sz.y

proc startRender*(window: Window, openglVersion: (int, int)) =

  let scale = window.getScaleInfo()
  
  if app.autoUiScale:
    app.uiScale = min(scale.x, scale.y)

  if app.fullscreen:
    window.fullscreen = app.fullscreen
  else:

    app.windowRawSize = app.windowSize.wh.scaled()
    window.size = ivec2(app.windowRawSize)

  if window.isNil:
    quit(
      "Failed to open window. GL version:" &
      &"{openglVersion[0]}.{$openglVersion[1]}"
    )

  window.makeContextCurrent()

  when not defined(emscripten):
    loadExtensions()

  # app.lastDraw = getTicks()
  # app.lastTick = app.lastDraw
  app.focused = true

  updateWindowSize(window)

static:
  ## compile check to ensure windy buttons don't change on us
  for i in 0..windy.Button.high().int:
    assert $Button(i) == $UiButton(i)

proc toUi(wbtn: windy.ButtonView): UiButtonView =
  when defined(nimscript):
    for b in set[Button](wbtn):
      result.incl UiButton(b.int)
  else:
    copyMem(addr result, unsafeAddr wbtn, sizeof(ButtonView))

var lastMouse = Mouse()

proc copyInputs(window: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  result.buttonRelease = toUi window.buttonReleased()
  result.buttonPress = toUi window.buttonPressed()
  result.buttonDown = toUi window.buttonDown()
  result.buttonToggle = toUi window.buttonToggle()

proc configureEvents(renderer: Renderer) =

  uxInputList = newChan[AppInputs](40)

  let window = renderer.window

  window.runeInputEnabled = true

  # window.onFrame = proc () =
  #   renderer.render(poll = false)

  window.onResize = proc () =
    updateWindowSize(window)
    renderer.render(updated = true, poll = false)
    var uxInput = window.copyInputs()
    uxInput.windowSize = some app.windowSize
    discard uxInputList.trySend(uxInput)

  window.onFocusChange = proc () =
    app.focused = window.focused
    let uxInput = window.copyInputs()
    discard uxInputList.trySend(uxInput)

  window.onMouseMove = proc () =
    var uxInput = AppInputs()
    let pos = vec2(window.mousePos())
    uxInput.mouse.pos = pos.descaled()
    let prevPos = vec2(window.mousePrevPos())
    uxInput.mouse.prev = prevPos.descaled()
    uxInput.mouse.consumed = false
    lastMouse = uxInput.mouse
    let res = uxInputList.trySend(uxInput)
    if res == false:
      echo "warning: mouse event blocked!"

  window.onScroll = proc () =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.mouse.consumed = false
    uxInput.mouse.wheelDelta = window.scrollDelta().descaled()
    # when defined(debugEvents):
    #   stdout.styledWriteLine({styleDim},
    #           fgWhite, "scroll ", {styleBright},
    #           fgGreen, $uxInput.mouse.wheelDelta.repr,
    #           )
    discard uxInputList.trySend(uxInput)

  window.onButtonPress = proc (button: windy.Button) =
    let uxInput = window.copyInputs()
    when defined(debugEvents):
      stdout.styledWriteLine({styleDim},
              fgWhite, "buttonPress ", {styleBright},
              fgGreen, $uxInput.buttonPress,
              fgWhite, "buttonRelease ",
              fgGreen, $uxInput.buttonRelease,
              fgWhite, "buttonDown ", {styleBright},
              fgGreen, $uxInput.buttonDown
              )
              # fgBlue, " time: " & $(time - lastButtonRelease) )
    discard uxInputList.trySend(uxInput)

  window.onButtonRelease = proc (button: Button) =
    let uxInput = window.copyInputs()
    when defined(debugEvents):
      stdout.styledWriteLine({styleDim},
              fgWhite, "release ",
              fgGreen, $button,
              fgWhite, "buttonRelease ",
              fgGreen, $uxInput.buttonRelease,
              fgWhite, "buttonDown ", {styleBright},
              fgGreen, $uxInput.buttonDown,
              fgWhite, "buttonPress ", {styleBright},
              fgGreen, $uxInput.buttonPress
              )
    discard uxInputList.trySend(uxInput)

  window.onRune = proc (rune: Rune) =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.keyboard.rune = some rune
    when defined(debugEvents):
      stdout.styledWriteLine({styleDim}, fgWhite, "keyboardInput: ",
                              {styleDim}, fgGreen, $rune)
    discard uxInputList.trySend(uxInput)

  # window.onImeChange = proc () =
  #   var uxInput = window.copyInputs()
  #   # uxInput.keyboard.ime = window.imeCompositionString()
  #   echo "ime: ", window.imeCompositionString()

  # internal.getWindowTitle = proc (): string =
  #   window.title
  # internal.setWindowTitle = proc (title: string) =
  #   if window != nil:
  #     window.title = title

  app.running = true

proc setupRenderer*(
    pixelate: bool,
    forcePixelScale: float32,
    atlasSize: int = 1024
): Renderer =

  app.pixelScale = forcePixelScale

  let renderer = Renderer()
  renderer.window = newWindow("", ivec2(1280, 800))
  renderer.window.makeContextCurrent()
  loadExtensions()
  renderer.ctx.entries = newTable[Hash, string]()
  renderer.ctx.boxy = newBoxy()

  renderer.configureEvents()
  app.requestedFrame.inc

  return renderer
  