
import std/unittest
import figuro/ui/textboxes
import figuro/ui/apis

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22'ui)
  smallFont = UiFont(typefaceId: typeface, size: 12'ui)

import pretty

suite "textboxes":
  setup:
    var text = newTextBox(initBox(0,0,100,100), font)
    for i in 1..4:
      text.insert(Rune(96+i))

  test "basic setup":
    check text.runes == "abcd".toRunes()
    check text.selection == 4..4

  test "basic insert extra":
    for i in 5..9:
      text.insert(Rune(96+i))
      check text.selection == i..i
      check text.runes == "abcdefghi".toRunes()[0..<i]
    check text.runes == "abcdefghi".toRunes()
    check text.selection == 9..9

  test "insert and re-insert":
    text.selection = 0..0
    text.insert(Rune('A'))
    check text.selection == 1..1
    check text.runes == "Aabcd".toRunes()
    print text
