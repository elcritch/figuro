
proc focus*(keyboard: Keyboard, node: Node, textBox: TextBox) =
  if keyboard.focusNode != node:
    keyboard.onUnFocusNode = keyboard.focusNode
    keyboard.onFocusNode = node
    keyboard.focusNode = node

    keyboard.input = node.text
    # currTextBox = node.userStates.mgetOrPut("$textbox", textBox)
    currTextBox = textBox
    currTextBox.editable = node.editableText
    currTextBox.scrollable = true
    requestedFrame.inc

proc focus*(keyboard: Keyboard, node: Node) =
  var font = fonts[node.textStyle.fontFamily]
  font.size = node.textStyle.fontSize.scaled
  font.lineHeight = node.textStyle.lineHeight.scaled
  if font.lineHeight == 0:
    font.lineHeight = defaultLineHeight(node.textStyle).scaled
  let textBox = newTextBox[Node](
    font,
    node.screenBox.w.scaled,
    node.screenBox.h.scaled,
    node,
    hAlignMode(current.textStyle.textAlignHorizontal),
    vAlignMode(current.textStyle.textAlignVertical),
    node.multiline,
    worldWrap = true,
  )
  keyboard.focus(node, textBox)


proc unFocus*(keyboard: Keyboard, node: Node) =
  if keyboard.focusNode == node:
    keyboard.onUnFocusNode = keyboard.focusNode
    keyboard.onFocusNode = nil
    keyboard.focusNode = nil
