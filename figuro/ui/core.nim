import std/[tables, unicode]
# import cssgrid

import commons
export commons

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var
  root* {.runtimeVar.}: Figuro
  parent* {.runtimeVar.}: Figuro
  current* {.runtimeVar.}: Figuro

  nodeStack* {.runtimeVar.}: seq[Figuro]
  # gridStack*: seq[GridTemplate]

  scrollBox* {.runtimeVar.}: Box
  scrollBoxMega* {.runtimeVar.}: Box ## Scroll box is 500px bigger in y direction
  scrollBoxMini* {.runtimeVar.}: Box ## Scroll box is smaller by 100px useful for debugging

  numNodes* {.runtimeVar.}: int
  popupActive* {.runtimeVar.}: bool
  inPopup* {.runtimeVar.}: bool
  resetNodes* {.runtimeVar.}: int
  popupBox* {.runtimeVar.}: Box

  # Used to check for duplicate ID paths.
  pathChecker* {.runtimeVar.}: Table[string, bool]

  computeTextLayout* {.runtimeVar.}: proc(node: Figuro)

  nodeLookup* {.runtimeVar.}: Table[string, Figuro]

  defaultlineHeightRatio* {.runtimeVar.} = 1.618.UICoord ##\
    ## see https://medium.com/@zkareemz/golden-ratio-62b3b6d4282a
  adjustTopTextFactor* {.runtimeVar.} = 1/16.0 # adjust top of text box for visual balance with descender's -- about 1/8 of fonts, so 1/2 that

  # global scroll bar settings
  scrollBarFill* {.runtimeVar.} = rgba(187, 187, 187, 162).color 
  scrollBarHighlight* {.runtimeVar.} = rgba(137, 137, 137, 162).color

  # buttonPress*: ButtonView
  # buttonDown*: ButtonView
  # buttonRelease*: ButtonView


# inputs.keyboardInput = proc (rune: Rune) =
#     app.requestedFrame.inc
#     # if keyboard.focusNode != nil:
#     #   keyboard.state = KeyState.Press
#     #   # currTextBox.typeCharacter(rune)
#     # else:
#     #   keyboard.state = KeyState.Press
#     #   keyboard.keyString = rune.toUTF8()
#     appEvent.trigger()

proc setupRoot*(widget: Figuro) =
  if root == nil:
    root = Figuro()
    root.uid = newUId()
    root.zlevel = ZLevelDefault
  # root = widget
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
          # and kind == current.kind:
      # Same node.
      discard
    else:
      # Big change.
      current.nIndex = parent.diffIndex
      # current.resetToDefault()
      refresh()

  {.cast(uncheckedAssign).}:
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
  preNode(kind, Figuro, id)
  setup
  inner
  postNode()

template node*(kind: NodeKind, id: static string, inner: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, Figuro, id)
  inner
  postNode()

proc computeScreenBox*(parent, node: Figuro, depth: int = 0) =
  ## Setups screenBoxes for the whole tree.
  if parent == nil:
    node.box.w = app.windowSize.x
    node.box.h = app.windowSize.y
    node.screenBox = node.box
    node.totalOffset = node.offset
  else:
    node.screenBox = node.box + parent.screenBox
    node.totalOffset = node.offset + parent.totalOffset

  # if depth == 0: echo ""
  # var sp = ""
  # for i in 0..depth: sp &= "  "
  # echo "node: ", sp, node.uid, " ", node.screenBox

  for n in node.children:
    computeScreenBox(node, n, depth + 1)
