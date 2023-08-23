import std/[os, hashes, strformat, strutils, tables, times]

import chroma
# import typography, typography/svgfont
import pixie
import pixie/fonts
import windy

import opengl/[base, context, render]
import opengl/commons

type
  Renderer* = ref object
    window: Window
    nodes*: seq[Node]

const
  openglMajor {.intdefine.} = 3
  openglMinor {.intdefine.} = 3

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

  preInput()
  renderAndSwap(window, nodes)
  postInput()

proc renderLoop*(renderer: Renderer, poll = true) =
  renderLoop(renderer.window, renderer.nodes)

proc configureEvents(renderer: Renderer) =

  let window = renderer.window

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
    let pos = vec2(window.mousePos())
    uxInputs.mouse.pos = pos.descaled()
    let prevPos = vec2(window.mousePrevPos())
    uxInputs.mouse.prev = prevPos.descaled()
    uxInputs.mouse.consumed = false
    # app.requestedFrame.inc
    # appEvent.trigger()

  window.onButtonPress = proc (button: windy.Button) =
    app.requestedFrame.inc
    # appEvent.trigger()
    discard

  window.onButtonRelease = proc (button: Button) =
    # appEvent.trigger()
    app.requestedFrame.inc
    discard

  # internal.getWindowTitle = proc (): string =
  #   window.title
  # internal.setWindowTitle = proc (title: string) =
  #   if window != nil:
  #     window.title = title

  # app.running = true

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

  ctx = newContext(atlasSize = atlasSize, pixelate = pixelate, pixelScale = app.pixelScale)
  app.requestedFrame.inc

  useDepthBuffer(false)

  return renderer
  

