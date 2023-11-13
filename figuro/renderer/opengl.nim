import std/[options, unicode, hashes, strformat, strutils, tables, times]
import std/terminal

import pkg/pixie
import pkg/windy

import ../shared
import ../inputs
import ./opengl/utils
import ./opengl/window
import ./opengl/renderer

export Renderer, render

var lastMouse = Mouse()

proc copyInputs(window: Window): AppInputs =
  result = AppInputs(mouse: lastMouse)
  result.buttonRelease = toUi window.buttonReleased()
  result.buttonPress = toUi window.buttonPressed()
  result.buttonDown = toUi window.buttonDown()
  result.buttonToggle = toUi window.buttonToggle()

proc configureWindowEvents(renderer: Renderer) =
  renderer.uxInputList = newChan[AppInputs](40)

  let window = renderer.window

  window.runeInputEnabled = true

  window.onResize = proc () =
    updateWindowSize(window)
    renderer.render(updated = true, poll = false)
    var uxInput = window.copyInputs()
    uxInput.windowSize = some app.windowSize
    discard renderer.uxInputList.trySend(uxInput)
  
  window.onFocusChange = proc () =
    app.focused = window.focused
    let uxInput = window.copyInputs()
    discard renderer.uxInputList.trySend(uxInput)

  window.onMouseMove = proc () =
    var uxInput = AppInputs()
    let pos = vec2(window.mousePos())
    uxInput.mouse.pos = pos.descaled()
    let prevPos = vec2(window.mousePrevPos())
    uxInput.mouse.prev = prevPos.descaled()
    uxInput.mouse.consumed = false
    lastMouse = uxInput.mouse
    let res = renderer.uxInputList.trySend(uxInput)
    if res == false:
      echo "warning: mouse event blocked!"

  window.onScroll = proc () =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.mouse.consumed = false
    uxInput.mouse.wheelDelta = window.scrollDelta().descaled()
    discard renderer.uxInputList.trySend(uxInput)

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
    discard renderer.uxInputList.trySend(uxInput)

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
    discard renderer.uxInputList.trySend(uxInput)

  window.onRune = proc (rune: Rune) =
    var uxInput = AppInputs(mouse: lastMouse)
    uxInput.keyboard.rune = some rune
    when defined(debugEvents):
      stdout.styledWriteLine({styleDim}, fgWhite, "keyboardInput: ",
                              {styleDim}, fgGreen, $rune)
    discard renderer.uxInputList.trySend(uxInput)

  app.running = true

proc setupRenderer*(
    pixelate: bool,
    forcePixelScale: float32,
    atlasSize: int = 1024
): Renderer =
  let window = newWindow("", ivec2(1280, 800))
  window.startOpenGL(openglVersion)

  let renderer = newRenderer(window, pixelate, forcePixelScale, atlasSize)
  renderer.configureWindowEvents()
  app.requestedFrame.inc

  return renderer


