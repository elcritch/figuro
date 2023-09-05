import std/[unicode]
import pkg/vmath

import common/nodes/basics
import common/uimaths
export uimaths

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}


type
  KeyState* = enum
    Empty
    Up
    Down
    Repeat
    Press # Used for text input

  MouseCursorStyle* = enum
    Default
    Pointer
    Grab
    NSResize

  Mouse* = object
    pos*: Position
    prev*: Position
    delta*: Position
    wheelDelta*: Position
    consumed*: bool ## Consumed - need to prevent default action.
    clickedOutside*: bool ##

  Keyboard* = object
    state*: KeyState
    consumed*: bool ## Consumed - need to prevent default action.
    # focusNode*: Node
    # onFocusNode*: Node
    # onUnFocusNode*: Node
    input*: seq[Rune]
    textCursor*: int ## At which character in the input string are we
    selectionCursor*: int ## To which character are we selecting to
  
  MouseEventKinds* {.size: sizeof(int8).} = enum
    evClick
    evClickOut
    evHover
    evOverlapped
    evPress
    evDown
    evRelease
    evScroll
    evDrag

  EventKind* = enum
    Enter
    Exit

  KeyboardEventKinds* {.size: sizeof(int8).} = enum
    evKeyboardInput
    evKeyboardFocus
    evKeyboardFocusOut

  MouseEventFlags* = set[MouseEventKinds]
  KeyboardEventFlags* = set[KeyboardEventKinds]

  UiButton* = enum
    ButtonUnknown
    MouseLeft
    MouseRight
    MouseMiddle
    MouseButton4
    MouseButton5
    DoubleClick
    TripleClick
    QuadrupleClick
    Key0
    Key1
    Key2
    Key3
    Key4
    Key5
    Key6
    Key7
    Key8
    Key9
    KeyA
    KeyB
    KeyC
    KeyD
    KeyE
    KeyF
    KeyG
    KeyH
    KeyI
    KeyJ
    KeyK
    KeyL
    KeyM
    KeyN
    KeyO
    KeyP
    KeyQ
    KeyR
    KeyS
    KeyT
    KeyU
    KeyV
    KeyW
    KeyX
    KeyY
    KeyZ
    KeyBacktick     # `
    KeyMinus        # -
    KeyEqual        # =
    KeyBackspace
    KeyTab
    KeyLeftBracket  # [
    KeyRightBracket # ]
    KeyBackslash    # \
    KeyCapsLock
    KeySemicolon    # :
    KeyApostrophe   # '
    KeyEnter
    KeyLeftShift
    KeyComma        # ,
    KeyPeriod       # .
    KeySlash        # /
    KeyRightShift
    KeyLeftControl
    KeyLeftSuper
    KeyLeftAlt
    KeySpace
    KeyRightAlt
    KeyRightSuper
    KeyMenu
    KeyRightControl
    KeyDelete
    KeyHome
    KeyEnd
    KeyInsert
    KeyPageUp
    KeyPageDown
    KeyEscape
    KeyUp
    KeyDown
    KeyLeft
    KeyRight
    KeyPrintScreen
    KeyScrollLock
    KeyPause
    KeyF1
    KeyF2
    KeyF3
    KeyF4
    KeyF5
    KeyF6
    KeyF7
    KeyF8
    KeyF9
    KeyF10
    KeyF11
    KeyF12
    KeyNumLock
    Numpad0
    Numpad1
    Numpad2
    Numpad3
    Numpad4
    Numpad5
    Numpad6
    Numpad7
    Numpad8
    Numpad9
    NumpadDecimal   # .
    NumpadEnter
    NumpadAdd       # +
    NumpadSubtract  # -
    NumpadMultiply  # *
    NumpadDivide    # /
    NumpadEqual     # =

  UiButtonView* = set[UiButton]


const
  MouseButtons* = {
    MouseLeft,
    MouseRight,
    MouseMiddle,
    MouseButton4,
    MouseButton5,
    DoubleClick,
    TripleClick,
    QuadrupleClick
  }

type
  AppInputs* = object
    mouse*: Mouse
    keyboard*: Keyboard

    buttonPress*: UiButtonView
    buttonDown*: UiButtonView
    buttonRelease*: UiButtonView
    buttonToggle*: UiButtonView

var
  uxInputs* {.runtimeVar.} = AppInputs(mouse: Mouse(), keyboard: Keyboard())

var keyboardInput* {.runtimeVar.}: proc (rune: Rune)

proc click*(mouse: Mouse): bool =
  when defined(clickOnDown):
    return MouseButtons * uxInputs.buttonDown != {}
  else:
    return MouseButtons * uxInputs.buttonRelease != {}

proc down*(mouse: Mouse): bool =
  return MouseButtons * uxInputs.buttonDown != {}

proc release*(mouse: Mouse): bool =
  return MouseButtons * uxInputs.buttonRelease != {}

proc scrolled*(mouse: Mouse): bool =
  mouse.wheelDelta.x != 0.0'ui
