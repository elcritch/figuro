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
    keyString*: string
    altKey*: bool
    ctrlKey*: bool
    shiftKey*: bool
    superKey*: bool
    # focusNode*: Node
    # onFocusNode*: Node
    # onUnFocusNode*: Node
    input*: seq[Rune]
    textCursor*: int ## At which character in the input string are we
    selectionCursor*: int ## To which character are we selecting to
  
  MouseEventType* {.size: sizeof(int16).} = enum
    evClick
    evHover
    evOverlapped
    evPress
    evRelease

  EventKind* = enum
    Enter
    Exit

  KeyboardEventType* {.size: sizeof(int16).} = enum
    evKeyboardInput
    evKeyboardFocus
    evKeyboardFocusOut

  GestureEventType* {.size: sizeof(int16).} = enum
    evScroll
    evDrag # TODO: implement this!?

  MouseEventFlags* = set[MouseEventType]
  KeyboardEventFlags* = set[KeyboardEventType]
  GestureEventFlags* = set[GestureEventType]

  InputEvents* = object
    mouse*: MouseEventFlags
    gesture*: GestureEventFlags
  ListenEvents* = object
    mouse*: MouseEventFlags
    gesture*: GestureEventFlags

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

type
    MouseEvent* = object
      case kind*: MouseEventType
      of evClick: discard
      of evHover: discard
      of evOverlapped: discard
      of evPress: discard
      of evRelease: discard

    KeyboardEvent* = object
      case kind*: KeyboardEventType
      of evKeyboardInput: discard
      of evKeyboardFocus: discard
      of evKeyboardFocusOut: discard

    GestureEvent* = object
      case kind*: GestureEventType
      of evScroll: discard
      of evDrag: discard


const
  MouseButtons = [
    MouseLeft,
    MouseRight,
    MouseMiddle,
    MouseButton4,
    MouseButton5,
  ]

type
  AppInputs* = object
    mouse*: Mouse
    keyboard*: Keyboard
    buttonPress*: UiButtonView
    buttonDown*: UiButtonView
    buttonRelease*: UiButtonView
    buttonToggle*: UiButtonView
    # cursorStyle*: MouseCursorStyle ## Sets the mouse cursor icon
    # prevCursorStyle*: MouseCursorStyle

var
  uxInputs* {.runtimeVar.} = AppInputs(mouse: Mouse(), keyboard: Keyboard())

proc toEvent*(kind: MouseEventType): MouseEvent =
  MouseEvent(kind: kind)
proc toEvent*(kind: KeyboardEventType): KeyboardEvent =
  KeyboardEvent(kind: kind)
proc toEvent*(kind: GestureEventType): GestureEvent =
  GestureEvent(kind: kind)

var keyboardInput* {.runtimeVar.}: proc (rune: Rune)

proc click*(mouse: Mouse): bool =
  for mbtn in MouseButtons:
    if mbtn in uxInputs.buttonPress:
      return true

proc down*(mouse: Mouse): bool =
  for mbtn in MouseButtons:
    if mbtn in uxInputs.buttonDown:
      return true

proc scrolled*(mouse: Mouse): bool =
  mouse.wheelDelta.x != 0.0'ui

proc release*(mouse: Mouse): bool =
  for mbtn in MouseButtons:
    if mbtn in uxInputs.buttonRelease: return true

# proc consume*(keyboard: Keyboard) =
#   ## Reset the keyboard state consuming any event information.
#   keyboard.state = Empty
#   keyboard.keyString = ""
#   keyboard.altKey = false
#   keyboard.ctrlKey = false
#   keyboard.shiftKey = false
#   keyboard.superKey = false
#   keyboard.consumed = true

proc consume*(mouse: Mouse) =
  ## Reset the mouse state consuming any event information.
  uxInputs.buttonPress.excl MouseLeft

# proc setMousePos*(item: var Mouse, x, y: float64) =
#   item.pos = vec2(x, y)
#   item.pos *= pixelRatio / item.pixelScale
#   item.delta = item.pos - item.prevPos
#   item.prevPos = item.pos
