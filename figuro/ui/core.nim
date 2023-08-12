import std/[tables, unicode]
# import cssgrid

import commons
export commons

var
  parent, current*: Figuro

  nodeStack*: seq[Figuro]
  # gridStack*: seq[GridTemplate]

  scrollBox*: Box
  scrollBoxMega*: Box ## Scroll box is 500px bigger in y direction
  scrollBoxMini*: Box ## Scroll box is smaller by 100px useful for debugging

  numNodes*: int
  popupActive*: bool
  inPopup*: bool
  resetNodes*: int
  popupBox*: Box

  # Used to check for duplicate ID paths.
  pathChecker*: Table[string, bool]

  computeTextLayout*: proc(node: Figuro)

  nodeLookup*: Table[string, Figuro]

  defaultlineHeightRatio* = 1.618.UICoord ##\
    ## see https://medium.com/@zkareemz/golden-ratio-62b3b6d4282a
  adjustTopTextFactor* = 1/16.0 # adjust top of text box for visual balance with descender's -- about 1/8 of fonts, so 1/2 that

  # global scroll bar settings
  scrollBarFill* = rgba(187, 187, 187, 162).color 
  scrollBarHighlight* = rgba(137, 137, 137, 162).color

  # buttonPress*: ButtonView
  # buttonDown*: ButtonView
  # buttonRelease*: ButtonView


inputs.keyboardInput = proc (rune: Rune) =
    app.requestedFrame.inc
    # if keyboard.focusNode != nil:
    #   keyboard.state = KeyState.Press
    #   # currTextBox.typeCharacter(rune)
    # else:
    #   keyboard.state = KeyState.Press
    #   keyboard.keyString = rune.toUTF8()
    appEvent.trigger()

proc setupRoot*(root: var Figuro) =
  if root == nil:
    root = Figuro()
    root.uid = newUId()
    root.zlevel = ZLevelDefault
  nodeStack = @[root]
  current = root
  root.diffIndex = 0

proc removeExtraChildren*(node: Figuro) =
  ## Deal with removed nodes.
  node.children.setLen(node.diffIndex)

proc refresh*() =
  ## Request the screen be redrawn
  app.requestedFrame = max(1, app.requestedFrame)

proc getTitle*(): string =
  ## Gets window title
  getWindowTitle()

proc setTitle*(title: string) =
  ## Sets window title
  if (getWindowTitle() != title):
    setWindowTitle(title)
    refresh()

proc preNode*[T: Figuro](kind: NodeKind, tp: typedesc[T], id: string) =
  ## Process the start of the node.
  mixin draw

  parent = nodeStack[^1]

  # TODO: maybe a better node differ?
  if parent.children.len <= parent.diffIndex:
    # Create Node.
    current = T()
    current.uid = newUId()
    parent.children.add(current)
    refresh()
  else:
    # Reuse Node.
    current = parent.children[parent.diffIndex]

    if not (current of T):
      # mismatch types, replace node
      echo "new type"
      current = T()
      parent.children[parent.diffIndex] = current

    if resetNodes == 0 and
        current.nIndex == parent.diffIndex:
      # Same node.
      discard
    else:
      # Big change.
      current.nIndex = parent.diffIndex
      # current.resetToDefault()
      refresh()

  current.kind = kind
  # current.textStyle = parent.textStyle
  # current.cursorColor = parent.cursorColor
  current.highlight = parent.highlight
  current.transparency = parent.transparency
  current.zlevel = parent.zlevel
  nodeStack.add(current)
  inc parent.diffIndex

  current.diffIndex = 0
  draw(T(current))

proc postNode*() =
  current.removeExtraChildren()

  # Pop the stack.
  discard nodeStack.pop()
  if nodeStack.len > 1:
    current = nodeStack[^1]
  else:
    current = nil
  if nodeStack.len > 2:
    parent = nodeStack[^2]
  else:
    parent = nil

template node*(kind: NodeKind, id: static string, inner, setup: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, Figuro, atom(id))
  setup
  inner
  postNode()

template node*(kind: NodeKind, id: static string, inner: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, Figuro, atom(id))
  inner
  postNode()

proc computeScreenBox*(parent, node: Figuro) =
  ## Setups screenBoxes for the whole tree.
  if parent == nil:
    node.screenBox = node.box
    node.totalOffset = node.offset
  else:
    node.screenBox = node.box + parent.screenBox
    node.totalOffset = node.offset + parent.totalOffset
  for n in node.children:
    computeScreenBox(node, n)