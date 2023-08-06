
proc computeTextLayout(node: Node) =
  var font = fonts[node.textStyle.fontFamily]
  font.size = node.textStyle.fontSize.scaled.float32
  font.lineHeight = node.textStyle.lineHeight.scaled.float32
  if font.lineHeight == 0:
    font.lineHeight = defaultLineHeight(node.textStyle).scaled.float32
  var
    boundsMin: Vec2
    boundsMax: Vec2
    size: Vec2 = node.box.scaled.wh
  if node.textStyle.autoResize == tsWidthAndHeight:
    size.x = 0
  node.textLayout = font.typeset(
    node.text,
    pos = vec2(0, 0),
    size = size,
    hAlignMode(node.textStyle.textAlignHorizontal),
    vAlignMode(node.textStyle.textAlignVertical),
    clip = false,
    boundsMin = boundsMin,
    boundsMax = boundsMax
  )
  let bMin = boundsMin.descaled
  let bMax = boundsMin.descaled
  node.textLayoutWidth = bMax.x - bMin.x
  node.textLayoutHeight = bMax.y - bMin.y
  # echo fmt"{boundsMin=} {boundsMax=}"

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
    app.requestedFrame.inc

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
