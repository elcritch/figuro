import std/[unicode, sequtils]
import pkg/vmath
import pkg/patty

import nodes/basics
import uimaths, keys
export uimaths, keys

type
  FrameStyle* {.pure.} = enum
    DecoratedResizable, DecoratedFixedSized, Undecorated, Transparent

variantp RenderCommands:
  RenderNoop
  RenderQuit
  RenderSetTitle(name: string)

type AppInputs* = object
  empty*: bool
  mouse*: Mouse
  keyboard*: Keyboard

  buttonPress*: UiButtonView
  buttonDown*: UiButtonView
  buttonRelease*: UiButtonView
  buttonToggle*: UiButtonView

  windowSize*: Option[Box]

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
