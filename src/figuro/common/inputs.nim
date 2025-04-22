import std/[unicode, sequtils]
import pkg/vmath
import pkg/patty

import nodes/basics
import nodes/render
import uimaths, keys

export uimaths, keys

type
  AppInputs* = object
    empty*: bool
    mouse*: Mouse
    keyboard*: Keyboard

    buttonPress*: UiButtonView
    buttonDown*: UiButtonView
    buttonRelease*: UiButtonView
    buttonToggle*: UiButtonView

    appWindow*: Option[AppWindow]

  AppWindow* = object
    box*: Box ## Screen size in logical coordinates.
    running*, focused*, minimized*, fullscreen*: bool
    pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels

  FrameConfig* = object
    pos*: IVec2 = ivec2(100, 100)
    size*: IVec2 = ivec2(0, 0)


variantp RenderCommands:
  RenderQuit
  RenderUpdate(n: Renders, window: AppWindow)
  RenderSetTitle(name: string)


proc click*(inputs: AppInputs): bool =
  when defined(clickOnDown):
    return MouseButtons * inputs.buttonDown != {}
  else:
    return MouseButtons * inputs.buttonRelease != {}

proc down*(inputs: AppInputs): bool =
  return MouseButtons * inputs.buttonDown != {}

proc release*(inputs: AppInputs): bool =
  return MouseButtons * inputs.buttonRelease != {}

proc scrolled*(inputs: AppInputs): bool =
  inputs.mouse.wheelDelta.x != 0.0'ui

proc dragging*(inputs: AppInputs): bool =
  return MouseButtons * inputs.buttonDown != {}
  return MouseButtons * inputs.buttonRelease != {}
