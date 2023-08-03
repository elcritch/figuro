import std/strutils, std/tables, std/deques
import cdecl/atoms
import cdecl/[atoms, crc32]
import chroma

import commonutils, common

export atoms

type
  Themer = proc()

  Themes* = TableRef[Atom, ref Deque[Themer]]

  Palette* = object
    primary*: Color
    link*: Color
    info*: Color
    success*: Color
    warning*: Color
    danger*: Color
    textModeLight*: Color
    textModeDark*: Color

  BasicTheme* = object
    foreground*: Color
    accent*: Color
    highlight*: Color
    disabled*: Color
    background*: Color
    text*: Color
    cursor*: Color
    cornerRadius*: (UICoord, UICoord, UICoord, UICoord)
    shadow*: Option[Shadow]
    gloss*: ImageStyle
    textStyle*: TextStyle
    innerStroke*: Stroke
    outerStroke*: Stroke
    itemSpacing*: UICoord

var
  palette*: Palette
  theme*: BasicTheme
  themes: Themes = newTable[Atom, ref Deque[Themer]]()

  noStroke* = Stroke.init(0.0'f32, "#000000", 0.0)

proc `..`*(a, b: Atom): Atom =
  b !& Atom(0xAAAAAAAA) !& a

proc `/`*(a, b: Atom): Atom =
  b !& a

proc peekLast(themes: ref Deque[Themer]): Themer =
  if themes.isNil: nil else: themes[].peekLast()

proc `[]`*(themes: Themes, name: Atom): Themer =
  themes.getOrDefault(name, nil).peekLast()

proc push*(themes: Themes, name: Atom, theme: Themer) =
  themes.mgetOrPut(name, new(ref Deque[Themer]))[].addLast(theme)

proc pop*(themes: Themes, name: Atom) =
  themes.mgetOrPut(name, new(ref Deque[Themer]))[].popLast()

template onTheme*(themes: Themes, name: Atom, blk: untyped) =
  if name in themes:
    `blk`

proc useThemeImpl(idPath: seq[Atom], extra: Atom) =
  template runThemerIfFound(value: untyped) =
    let themer = themes.getOrDefault(value, nil).peekLast()
    if not themer.isNil:
      themer()
      return

  let id = idPath[^1]
  runThemerIfFound(extra !& id !& idPath[^2]) # check parent
  for idx in countdown(idPath.len()-2, 0):
    # check skip matches
    runThemerIfFound(extra !& id !& Atom(0xAAAAAAAA) !& idPath[idx])
  
  # check self
  runThemerIfFound(extra !& id)
  # check attribute if given
  if extra != Atom(0):
    runThemerIfFound(extra)
  

template useTheme*() =
  useThemeImpl(current.idPath, Atom(0))

template useTheme*(name: Atom) =
  useThemeImpl(current.idPath, name)

template setTheme*(name: Atom, blk: untyped) =
  let themer = proc() =
    `blk`
  themes.push(name, themer)

proc setFontStyle*(
  textStyle: var TextStyle,
  fontFamily: string,
  fontSize, fontWeight, lineHeight: float32,
  textAlignHorizontal: HAlign,
  textAlignVertical: VAlign
) =
  ## Sets the font.
  textStyle = TextStyle()
  textStyle.fontFamily = fontFamily
  textStyle.fontSize = fontSize.UICoord
  textStyle.fontWeight = fontWeight.UICoord
  textStyle.lineHeight =
      if lineHeight != 0.0: lineHeight.UICoord
      else: defaultLineHeight(textStyle)
  textStyle.textAlignHorizontal = textAlignHorizontal
  textStyle.textAlignVertical = textAlignVertical

proc font*(
  item: var BasicTheme,
  fontFamily: string,
  fontSize, fontWeight, lineHeight: float32,
  textAlignHorizontal: HAlign,
  textAlignVertical: VAlign
) =
  item.textStyle.setFontStyle(
    fontFamily,
    fontSize,
    fontWeight,
    lineHeight,
    textAlignHorizontal,
    textAlignVertical)

proc fill*(item: var BasicTheme) =
  ## Sets background color.
  current.fill = item.foreground

proc strokeLine*(item: var Palette, weight: float32, color: string, alpha = 1.0) =
  ## Sets stroke/border color.
  current.stroke.color = parseHtmlColor(color)
  current.stroke.color.a = alpha
  current.stroke.weight = weight 
