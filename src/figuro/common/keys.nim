import std/[unicode, sequtils]
import pkg/vmath

import nodes/basics
import uimaths
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

  Keyboard* = object
    consumed*: bool ## Consumed - need to prevent default action.
    rune*: Option[Rune]
    textCursor*: int ## At which character in the input string are we
    selectionCursor*: int ## To which character are we selecting to

  EventKinds* {.size: sizeof(int8).} = enum
    evClick
    evClickOut
    evHover
    evOverlapped
    evPress
    evDown
    evRelease
    evScroll
    evDrag
    evDragEnd
    evKeyboardInput
    evKeyPress

  EventKind* = enum
    Exit
    Enter

  EventFlags* = set[EventKinds]

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
    KeyBacktick # `
    KeyMinus # -
    KeyEqual # =
    KeyBackspace
    KeyTab
    KeyLeftBracket # [
    KeyRightBracket # ]
    KeyBackslash # \
    KeyCapsLock
    KeySemicolon # :
    KeyApostrophe # '
    KeyEnter
    KeyLeftShift
    KeyComma # ,
    KeyPeriod # .
    KeySlash # /
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
    NumpadDecimal # .
    NumpadEnter
    NumpadAdd # +
    NumpadSubtract # -
    NumpadMultiply # *
    NumpadDivide # /
    NumpadEqual # =

  UiButtonView* = set[UiButton]
  KeyRange* = KeyA .. NumpadEqual

const
  MouseButtons* = {
    MouseLeft, MouseRight, MouseMiddle, MouseButton4, MouseButton5, DoubleClick,
    TripleClick, QuadrupleClick,
  }

  ModifierButtons* = {
    KeyLeftControl, KeyRightControl, KeyLeftSuper, KeyRightSuper, KeyLeftAlt,
    KeyRightAlt, KeyLeftShift, KeyRightShift, KeyMenu,
  }

type ModifierKeys* = enum
  KNone
  KMeta
  KControl
  KAlt
  KShift
  KMenu
