import windy/common

export common

type
  ModKey* = enum
    SHIFT = 0x0001
    CONTROL = 0x0002
    ALT = 0x0004
    SUPER = 0x0008

  Buttons* = object
    down*: ButtonView
    release*: ButtonView
    toggle*: ButtonView
    press*: ButtonView

var
  buttons*: Buttons


when defined(js):
  import tables

  let mouseButtonToButton* = {
    0: MOUSE_LEFT,
    2: MOUSE_RIGHT,
    1: MOUSE_MIDDLE,
    3: MOUSE_BACK,
    4: MOUSE_FORWARD,
  }.toTable()

  let keyCodeToButton* = {
    32: SPACE,
    222: APOSTROPHE,
    188: COMMA,
    189: MINUS,
    190: PERIOD,
    191: SLASH,
    48: NUMBER_0,
    49: NUMBER_1,
    50: NUMBER_2,
    51: NUMBER_3,
    52: NUMBER_4,
    53: NUMBER_5,
    54: NUMBER_6,
    55: NUMBER_7,
    56: NUMBER_8,
    57: NUMBER_9,
    186: SEMICOLON,
    187: EQUAL,
    65: LETTER_A,
    66: LETTER_B,
    67: LETTER_C,
    68: LETTER_D,
    69: LETTER_E,
    70: LETTER_F,
    71: LETTER_G,
    72: LETTER_H,
    73: LETTER_I,
    74: LETTER_J,
    75: LETTER_K,
    76: LETTER_L,
    77: LETTER_M,
    78: LETTER_N,
    79: LETTER_O,
    80: LETTER_P,
    81: LETTER_Q,
    82: LETTER_R,
    83: LETTER_S,
    84: LETTER_T,
    85: LETTER_U,
    86: LETTER_V,
    87: LETTER_W,
    88: LETTER_X,
    89: LETTER_Y,
    90: LETTER_Z,
    219: LEFT_BRACKET,
    220: BACKSLASH,
    221: RIGHT_BRACKET,
    192: GRAVE_ACCENT,
    0: WORLD_1,
    0: WORLD_2,

    # Function keys
    27: ESCAPE,
    13: ENTER,
    9: TAB,
    8: BACKSPACE,
    45: INSERT,
    46: DELETE,
    39: ARROW_RIGHT,
    37: ARROW_LEFT,
    40: ARROW_DOWN,
    38: ARROW_UP,
    33: PAGE_UP,
    34: PAGE_DOWN,
    36: HOME,
    35: END,
    20: CAPS_LOCK,
    145: SCROLL_LOCK,
    144: NUM_LOCK,
    44: PRINT_SCREEN,
    19: PAUSE,
    112: F1,
    113: F2,
    114: F3,
    115: F4,
    116: F5,
    117: F6,
    118: F7,
    119: F8,
    120: F9,
    121: F10,
    122: F11,
    124: F12,
    96: KP_0,
    97: KP_1,
    98: KP_2,
    99: KP_3,
    100: KP_4,
    101: KP_5,
    102: KP_6,
    103: KP_7,
    104: KP_8,
    105: KP_9,
    110: KP_DECIMAL,
    111: KP_DIVIDE,
    106: KP_MULTIPLY,
    109: KP_SUBTRACT,
    107: KP_ADD,
    0: KP_ENTER,
    0: KP_EQUAL,

    16: LEFT_SHIFT,
    17: LEFT_CONTROL,
    18: LEFT_ALT,
    91: LEFT_SUPER,
    0: RIGHT_SHIFT,
    0: RIGHT_CONTROL,
    0: RIGHT_ALT,
    92: RIGHT_SUPER,

    93: LEFT_SUPER

  }.toTable()
