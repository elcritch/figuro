import std/[os, hashes, strformat, strutils, tables, times]
import std/terminal

import pkg/pixie
import pkg/windy

import ../inputs
import opengl/[base, context, render]
import opengl/commons

type
  Renderer* = ref object
    window: Window
    nodes*: RenderNodes
    updated*: bool

const
  openglMajor {.intdefine.} = 3
  openglMinor {.intdefine.} = 3

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

proc renderLoop(window: Window,
                nodes: var RenderNodes,
                updated: bool,
                poll = true) =
  if window.closeRequested:
    app.running = false
    return

  timeIt(eventPolling):
    if poll:
      windy.pollEvents()
  
  preInput()
  if updated:
    renderAndSwap(window, nodes, updated)
  postInput()

var lastMouse = Mouse()

proc renderLoop*(renderer: Renderer, poll = true) =
  let update = renderer.updated
  renderer.updated = false
  renderLoop(renderer.window, renderer.nodes, update)

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

  window.onResize = proc () =
    updateWindowSize(window)
    renderLoop(window, renderer.nodes, true, poll = false)
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

  let openglVersion = (openglMajor, openglMinor)
  app.pixelScale = forcePixelScale

  let renderer =
    Renderer(window: newWindow("", ivec2(1280, 800)))

  renderer.window.startOpenGL(openglVersion)
  renderer.configureEvents()

  ctx = newContext(atlasSize = atlasSize,
                    pixelate = pixelate,
                    pixelScale = app.pixelScale)
  app.requestedFrame.inc

  useDepthBuffer(false)

  return renderer
  

