
import std/unittest
import figuro/ui/textboxes
import figuro/ui/apis

let
  typeface = defaultTypeface()
  font = UiFont(typefaceId: typeface, size: 22'ui)
  smallFont = UiFont(typefaceId: typeface, size: 12'ui)

import pretty

suite "text boxes (single line)":
  setup:
    var box = initBox(0,0,100,100)
    var text = newTextBox(box, font)
    for c in ['a', 'b', 'c', 'd']:
      text.insert(Rune(c))
    text.update(box)

  test "basic setup":
    check text.runes == "abcd".toRunes()
    check text.selection == 4..4

  test "selection":
    check text.selected() == "".toRunes()
    text.selection = 0..1
    check text.selected() == "a".toRunes()
    text.selection = 0..2
    check text.selected() == "ab".toRunes()
    text.selection = 0..0

  test "rune at cursor":
    text.selection = 0..0
    check text.runeAtCursor() == "a".runeAt(0)
    text.selection = 0..1
    check text.runeAtCursor() == "a".runeAt(0)
    text.selection = 3..3
    check text.runeAtCursor() == "d".runeAt(0)

  test "basic insert extra":
    for i in 5..9:
      text.insert(Rune(96+i))
      check text.selection == i..i
      check text.runes == "abcdefghi".toRunes()[0..<i]
    check text.runes == "abcdefghi".toRunes()
    check text.selection == 9..9

  test "basic deletes":
    text.selection = 4..4
    for i in countdown(3,0):
      text.delete(Left)
      check text.selection == i..i
      check text.runes == "abcd".toRunes()[0..<i]
    check text.runes == "".toRunes()
    check text.selection == 0..0

  test "insert at beginning":
    text.shiftCursor(Beginning)
    text.insert(Rune('A'))
    check text.selection == 1..1
    check text.runes == "Aabcd".toRunes()

  test "re-insert selected":
    text.selection = 0..1
    text.insert(Rune('A'))
    check text.selection == 1..1
    check text.runes == "Abcd".toRunes()

  test "re-insert selected offset":
    text.selection = 1..2
    text.insert(Rune('B'))
    check text.selection == 2..2
    check text.runes == "aBcd".toRunes()

  test "re-insert at end":
    text.selectionRange = 4..4
    text.insert(Rune('E'))
    check text.selection == 5..5
    check text.runes == "abcdE".toRunes()

  test "double-insert":
    text.selection = 1..3
    text.insert(Rune('B'))
    check text.selection == 2..2
    check text.runes == "aBd".toRunes()

  test "cursor right":
    text.selection = 0..0
    for i in 1..4:
      text.shiftCursor(Right)
      check text.selection == i..i
    # extra should clamp
    text.shiftCursor(Right)
    check text.selection == 4..4
    check text.runes == "abcd".toRunes()

  test "cursor grow right":
    text.selection = 0..0
    for i in 1..4:
      text.shiftCursor(Right, select = true)
      check text.selection == 0..i
    # extra should clamp
    text.shiftCursor(Right, select = true)
    check text.selection == 0..4
    check text.runes == "abcd".toRunes()

  test "cursor left":
    text.selection = 4..4
    for i in countdown(3,0):
      text.shiftCursor(Left)
      check text.selection == i..i
    # extra should clamp
    text.shiftCursor(Left)
    check text.selection == 0..0
    check text.runes == "abcd".toRunes()

  test "cursor grow left":
    text.selection = 4..4
    for i in countdown(3,0):
      text.shiftCursor(Left, select = true)
      check text.selection == i..4
    # extra should clamp
    text.shiftCursor(Left, select = true)
    check text.selection == 0..4
    check text.runes == "abcd".toRunes()

  test "cursor up":
    text.selection = 2..2
    text.shiftCursor(Up)
    check text.selection == 0..0
    check text.runes == "abcd".toRunes()

  test "cursor up grow":
    text.selection = 2..2
    text.shiftCursor(Up, select=true)
    check text.selection == 0..2
    check text.runes == "abcd".toRunes()

  test "cursor down":
    text.selection = 2..2
    text.shiftCursor(Down)
    check text.selection == 4..4
    check text.runes == "abcd".toRunes()

  test "cursor down grow":
    text.selection = 2..2
    text.shiftCursor(Down, select=true)
    check text.selection == 2..4
    check text.runes == "abcd".toRunes()

  test "inserts":
    var tx = newTextBox(initBox(0,0,100,100), font)
    tx.insert("one".toRunes)
    check tx.selection == 3..3
    check tx.runes == "one".toRunes()

  test "set text":
    var tx = newTextBox(initBox(0,0,100,100), font)
    tx.insert("one".toRunes)
    tx.replaceText("alpha".toRunes)
    check tx.selection == 3..3
    check tx.runes == "alpha".toRunes()

  test "set text selected":
    var tx = newTextBox(box, font)
    tx.insert("one".toRunes)
    tx.selection = 0..2

    tx.replaceText("alpha".toRunes)
    check tx.selection == 0..2
    check tx.runes == "alpha".toRunes()

  test "set text overwrite":
    text.placeCursor(0)
    text.insert("o".runeAt(0), overWrite = true)
    check text.runes == "obcd".toRunes()
    text.placeCursor(0)
    text.insert("u".runeAt(0), true)
    check text.runes == "ubcd".toRunes()

    text.placeCursor(1)
    text.insert("x".runeAt(0), true)
    check text.runes == "uxcd".toRunes()
    text.placeCursor(1)
    text.insert("y".runeAt(0), true)
    check text.runes == "uycd".toRunes()

  test "set text overwrite end, with rangelimit":
    text.selection = 4..4
    text.insert("x".runeAt(0), true, rangeLimit = 4)
    check text.runes == "abcd".toRunes()

    text.selection = 3..3
    text.insert("x".runeAt(0), true, 4)
    check text.runes == "abcx".toRunes()

  test "set text overwrite selected":
    text.selection = 2..3
    text.insert("o".runeAt(0), true)
    check text.runes == "abo".toRunes()

  test "set text overwrite many selected":
    text.selection = 2..4
    text.placeCursor(2)
    text.insert("xy".toRunes(), true)
    check text.runes == "abxy".toRunes()

  test "set text overwrite many selected":
    text.selection = 4..4
    text.insert("x".toRunes(), true)
    check text.runes == "abcd".toRunes()

  test "set text overwrite single":
    text.selection = 0..0
    text.insert("x".toRunes(), true)
    check text.runes == "xbcd".toRunes()

  test "set text overwrite multiple":
    text.selection = 0..0
    text.insert("xy".toRunes(), true)
    check text.runes == "xycd".toRunes()

  test "set text with longer selected text":
    var tx = newTextBox(box, font)
    tx.insert("alpha".toRunes)
    tx.selection = 0..4

    tx.replaceText("one".toRunes)
    check tx.selection == 0..3
    check tx.runes == "one".toRunes()

  test "cursor grow direction handling (Right)":
    text.selection = 0..0
    text.shiftCursor(Right, select = true)
    check text.selection == 0..1
    text.shiftCursor(Right, select = true)
    check text.selection == 0..2
    text.shiftCursor(Left, select = true)
    check text.selection == 0..1
    text.shiftCursor(Left, select = true)
    check text.selection == 0..0
    check text.runes == "abcd".toRunes()

  test "cursor grow direction handling (Left)":
    text.selection = 2..2
    text.shiftCursor(Left, select = true)
    check text.selection == 1..2
    text.shiftCursor(Left, select = true)
    check text.selection == 0..2
    text.shiftCursor(Right, select = true)
    check text.selection == 1..2
    text.shiftCursor(Right, select = true)
    check text.selection == 2..2
    check text.runes == "abcd".toRunes()

suite "textboxes (two line)":
  setup:
    var box = initBox(0,0,100,100)
    var text = newTextBox(box, font)
    text.insert("one\ntwos".toRunes)
    text.update(box)

  test "basic":
    check text.runes == "one\ntwos".toRunes()
    check text.selection == 8..8

  test "cursor up":
    text.selection = 6..6
    text.shiftCursor(Up)
    check text.selection == 2..2

    text.selection = 5..5
    text.shiftCursor(Up)
    check text.selection == 1..1

    text.selection = 7..7
    text.shiftCursor(Up)
    check text.selection == 3..3

    text.selection = 8..8
    text.shiftCursor(Up)
    check text.selection == 3..3
    check text.runes == "one\ntwos".toRunes()

  test "cursor up grow":
    text.selection = 6..6
    text.shiftCursor(Up, select = true)
    check text.selection == 2..6
    text.shiftCursor(Up, select = true)
    check text.selection == 0..6
    check text.runes == "one\ntwos".toRunes()

  test "cursor down":
    text.selection = 2..2
    text.shiftCursor(Down)
    check text.selection == 6..6
    text.selection = 3..3
    text.shiftCursor(Down)
    check text.selection == 7..7
    check text.runes == "one\ntwos".toRunes()

  test "cursor down grow":
    text.selection = 2..2
    text.shiftCursor(Down, select=true)
    check text.selection == 2..6
    check text.runes == "one\ntwos".toRunes()

suite "textboxes (three line)":
  setup:
    var box = initBox(0,0,100,100)
    var text = newTextBox(box, font)
    text.insert("one\ntwos\nthrees".toRunes)
    text.update(box)

  test "basic":
    check text.runes == "one\ntwos\nthrees".toRunes()
    check text.selection == 15..15

  test "cursor up":
    text.selection = 10..10
    text.shiftCursor(Up)
    check text.selection == 5..5

    text.selection = 11..11
    text.shiftCursor(Up)
    check text.selection == 6..6

    text.selection = 12..12
    text.shiftCursor(Up)
    check text.selection == 7..7

    text.selection = 14..14
    text.shiftCursor(Up)
    check text.selection == 8..8

    text.selection = 15..15
    text.shiftCursor(Up)
    check text.selection == 8..8

    check text.runes == "one\ntwos\nthrees".toRunes()

  test "cursor up grow":
    text.selection = 6..6
    text.shiftCursor(Up, select=true)
    check text.selection == 2..6
    text.shiftCursor(Up, select=true)
    check text.selection == 0..6
    check text.runes == "one\ntwos\nthrees".toRunes()

  test "cursor down":
    text.selection = 2..2
    text.shiftCursor(Down)
    check text.selection == 6..6
    text.selection = 3..3
    text.shiftCursor(Down)
    check text.selection == 7..7
    check text.runes == "one\ntwos\nthrees".toRunes()

  test "cursor down grow":
    text.selection = 2..2
    text.shiftCursor(Down, select=true)
    check text.selection == 2..6
    check text.runes == "one\ntwos\nthrees".toRunes()

suite "textbox move words":
  setup:
    var box = initBox(0,0,100,100)
    var text = newTextBox(box, font)
    text.insert("one twos threes".toRunes)
    text.update(box)

  test "cursor word right":
    text.selection = 0..0
    text.shiftCursor(NextWord)
    check text.selection == 4..4

    text.selection = 5..5
    text.shiftCursor(NextWord)
    check text.selection == 9..9
    check text.runes == "one twos threes".toRunes()

  test "cursor word right grow":
    text.selection = 0..0
    text.shiftCursor(NextWord, select = true)
    check text.selection == 0..4

    text.selection = 5..5
    text.shiftCursor(NextWord, select = true)
    check text.selection == 5..9
    check text.runes == "one twos threes".toRunes()

  test "cursor word left":
    text.selection = 5..5
    text.shiftCursor(PreviousWord)
    check text.selection == 4..4

    text.shiftCursor(PreviousWord)
    check text.selection == 0..0
    check text.runes == "one twos threes".toRunes()
