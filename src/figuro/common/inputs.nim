

import pkg/patty

import nodes/basics
import nodes/render
import uimaths, keys
export uimaths, keys

type
  FrameStyle* {.pure.} = enum
    DecoratedResizable, DecoratedFixedSized, Undecorated, Transparent

  WindowInfo* = object
    box*: Box ## Screen size in logical coordinates.
    running*, focused*, minimized*, fullscreen*: bool
    pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels

variantp RenderCommands:
  RenderQuit
  RenderUpdate(n: Renders, window: WindowInfo)
  RenderSetTitle(name: string)

type AppInputs* = object
  empty*: bool
  mouse*: Mouse
  keyboard*: Keyboard

  buttonPress*: UiButtonView
  buttonDown*: UiButtonView
  buttonRelease*: UiButtonView
  buttonToggle*: UiButtonView

  window*: Option[WindowInfo]

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
