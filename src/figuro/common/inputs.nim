import pkg/patty
from pixie import Image

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

variantp ClipboardContents:
  ClipboardEmpty
  ClipboardStr(str: string)
  # ClipboardImg(img: Image)

variantp RenderCommands:
  RenderQuit
  RenderUpdate(n: Renders, winInfo: WindowInfo)
  RenderSetTitle(name: string)
  RenderClipboardGet
  RenderClipboard(cb: ClipboardContents)

type AppInputs* = object
  empty*: bool
  mouse*: Mouse
  keyboard*: Keyboard

  buttonPress*: set[UiMouse]
  buttonDown*: set[UiMouse]
  buttonRelease*: set[UiMouse]
  buttonToggle*: set[UiMouse]

  keyPress*: set[UiKey]
  keyDown*: set[UiKey]
  keyRelease*: set[UiKey]
  keyToggle*: set[UiKey]

  windowInfo*: Option[WindowInfo]

proc click*(inputs: AppInputs): bool =
  when defined(clickOnDown):
    return inputs.buttonDown != {}
  else:
    return inputs.buttonRelease != {}

proc down*(inputs: AppInputs): bool =
  return inputs.buttonDown != {}

proc release*(inputs: AppInputs): bool =
  return inputs.buttonRelease != {}

proc scrolled*(inputs: AppInputs): bool =
  inputs.mouse.wheelDelta.x != 0.0'ui

proc dragging*(inputs: AppInputs): bool =
  return inputs.buttonDown != {}
