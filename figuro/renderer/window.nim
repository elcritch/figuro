import std/[os, hashes, strformat, strutils, tables, times]
import pkg/pixie
import pkg/windy

import ../inputs
import opengl/[base, context, render]
import opengl/commons

type
  Renderer* = ref object
    window: Window
    nodes*: RenderNodes

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

proc renderLoop(window: Window, nodes: var RenderNodes, poll = true) =
  if window.closeRequested:
    app.running = false
    return

  timeIt(eventPolling):
    if poll:
      windy.pollEvents()
  
  if app.requestedFrame <= 0 or app.minimized:
    return
  else:
    app.requestedFrame.dec

  # echo "renderLoop: ", app.requestedFrame

  preInput()
  renderAndSwap(window, nodes)
  postInput()

var lastMouse = Mouse()

proc renderLoop*(renderer: Renderer, poll = true) =
  renderLoop(renderer.window, renderer.nodes)

import std/terminal

proc copyInputs(window: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  result.buttonRelease = toUi window.buttonReleased()
  result.buttonPress = toUi window.buttonPressed()
  result.buttonDown = toUi window.buttonDown()
  result.buttonToggle = toUi window.buttonToggle()
  result.keyboard.consumed = false

proc configureEvents(renderer: Renderer) =

  uxInputList = newChan[AppInputs](40)

  let window = renderer.window

  window.runeInputEnabled = true

  window.onResize = proc () =
    updateWindowSize(window)
    renderLoop(window, renderer.nodes, poll = false)
    var uxInput = window.copyInputs()
    uxInput.windowSize = some app.windowSize
    discard uxInputList.trySend(uxInput)
  
  window.onFocusChange = proc () =
    app.focused = window.focused
    # appEvent.trigger()

  window.onRune = keyboardInput

  window.onMouseMove = proc () =
    ## TODO: this is racey no?
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
    var uxInput = AppInputs()
    uxInput.mouse.wheelDelta = window.scrollDelta().descaled()
    discard uxInputList.trySend(uxInput)

  window.onButtonPress = proc (button: windy.Button) =
    let uxInput = window.copyInputs()
    stdout.styledWriteLine({styleDim},
            fgWhite, "buttonPress ", {styleBright},
            fgGreen, $uxInput.buttonPress)
            # fgBlue, " time: " & $(time - lastButtonRelease) )
    discard uxInputList.trySend(uxInput)

  window.onButtonRelease = proc (button: Button) =
    let uxInput = window.copyInputs()
    stdout.styledWriteLine({styleDim}, fgWhite, "buttonRelease ",
                            {styleDim}, fgGreen, $uxInput.buttonRelease)
    discard uxInputList.trySend(uxInput)

  window.onRune = proc (rune: Rune) =
    var uxInput = window.copyInputs()
    uxInput.keyboard.input.add rune
    echo "keyboard: ", uxInput.keyboard.input
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
  

