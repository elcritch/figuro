import std/[os, hashes, strformat, strutils, tables, times]
import pkg/pixie
import pkg/windy

import ../inputs
import opengl/[base, context, render]
import opengl/commons

type
  Renderer* = ref object
    window: Window
    nodes*: seq[Node]

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

proc renderLoop(window: Window, nodes: var seq[Node], poll = true) =
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

  echo "renderLoop: ", app.requestedFrame

  preInput()
  renderAndSwap(window, nodes)
  postInput()

proc renderLoop*(renderer: Renderer, poll = true) =
  renderLoop(renderer.window, renderer.nodes)

proc configureEvents(renderer: Renderer) =

  let window = renderer.window

  window.runeInputEnabled = true

  window.onResize = proc () =
    updateWindowSize(window)
    renderLoop(window, renderer.nodes, poll = false)
    # renderEvent.trigger()
  
  window.onFocusChange = proc () =
    app.focused = window.focused
    # appEvent.trigger()

  window.onScroll = proc () =
    app.requestedFrame.inc
    uxInputs.mouse.wheelDelta = window.scrollDelta().descaled
    # renderEvent.trigger()

  window.onRune = keyboardInput

  window.onMouseMove = proc () =
    ## TODO: this is racey no?
    let pos = vec2(window.mousePos())
    uxInputs.mouse.pos = pos.descaled()
    let prevPos = vec2(window.mousePrevPos())
    uxInputs.mouse.prev = prevPos.descaled()
    uxInputs.mouse.consumed = false
    # app.requestedFrame.inc
    # appEvent.trigger()
  window.onScroll = proc () =
    uxInputs.mouse.wheelDelta = window.scrollDelta().descaled()

  window.onButtonPress = proc (button: windy.Button) =
    uxInputs.buttonPress = toUi window.buttonPressed()
    uxInputs.buttonDown = toUi window.buttonDown()
    uxInputs.buttonToggle = toUi window.buttonToggle()
    uxInputs.keyboard.consumed = false
    echo "buttonPress: ", uxInputs.buttonPress

  window.onButtonRelease = proc (button: Button) =
    uxInputs.buttonPress = toUi window.buttonPressed()
    uxInputs.buttonDown = toUi window.buttonDown()
    uxInputs.buttonToggle = toUi window.buttonToggle()
    uxInputs.keyboard.consumed = false

  window.onRune = proc (rune: Rune) =
    uxInputs.keyboard.input.add rune
    echo "keyboard: ", uxInputs.keyboard.input
  window.onImeChange = proc () =
    echo "ime: ", window.imeCompositionString()


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
  

