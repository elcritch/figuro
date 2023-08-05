import std/[os, hashes, strformat, strutils, tables, times]

import pkg/chroma
import pkg/[typography, typography/svgfont]
import pkg/pixie
import pkg/windy

import opengl/[base, context, draw]
import opengl/commons

type
  Renderer* = ref object
    window: Window
    root: Node

const
  openglMajor {.intdefine.} = 3
  openglMinor {.intdefine.} = 3

proc renderLoop(window: Window, root: Node, poll = true) =
  if window.closeRequested:
    app.running = false
    return

  if poll:
    windy.pollEvents()
  
  if requestedFrame <= 0 or app.minimized:
    return
  requestedFrame.dec
  preInput()
  if tickMain != nil:
    preTick()
    tickMain()
    postTick()
  drawAndSwap(window, root)
  postInput()

proc renderLoop*(renderer: Renderer, poll = true) =
  renderLoop(renderer.window, renderer.root)

proc configureEvents(renderer: Renderer) =

  let window = renderer.window
  let root = renderer.root

  window.onResize = proc () =
    updateWindowSize(window)
    renderLoop(window, root, poll = false)
    renderEvent.trigger()
  
  window.onFocusChange = proc () =
    app.focused = window.focused
    appEvent.trigger()

  window.onScroll = proc () =
    requestedFrame.inc
    mouse.wheelDelta += window.scrollDelta().x
    renderEvent.trigger()

  window.onRune = keyboardInput

  window.onMouseMove = proc () =
    requestedFrame.inc
    appEvent.trigger()

  window.onButtonPress = proc (button: windy.Button) =
    requestedFrame.inc
    appEvent.trigger()

  window.onButtonRelease = proc (button: Button) =
    appEvent.trigger()

  internal.getWindowTitle = proc (): string =
    window.title
  internal.setWindowTitle = proc (title: string) =
    if window != nil:
      window.title = title

  app.running = true

proc setupRenderer*(
    pixelate: bool,
    forcePixelScale: float32,
    atlasSize: int = 1024
): Renderer =

  let openglVersion = (openglMajor, openglMinor)
  pixelScale = forcePixelScale

  let renderer =
    Renderer(window: newWindow("", ivec2(1280, 800)))

  renderer.window.startOpenGL(openglVersion)
  renderer.configureEvents()

  ctx = newContext(atlasSize = atlasSize, pixelate = pixelate, pixelScale = pixelScale)
  requestedFrame.inc

  useDepthBuffer(false)

  if loadMain != nil:
    loadMain()
  
  return renderer
  

