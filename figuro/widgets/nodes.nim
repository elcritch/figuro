import std/[tables, unicode]
import chroma
import cssgrid


import ../[common, commonutils]

import cdecl/atoms

from windy/common import Button, ButtonView

export chroma, common
export commonutils
export cssgrid

var
  parent*: Node
  root*: Node

  nodeStack*: seq[Node]
  gridStack*: seq[GridTemplate]
  current*: Node
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

  computeTextLayout*: proc(node: Node)

  lastUId: int
  nodeLookup*: Table[string, Node]

  ## Used for HttpCalls
  httpCalls*: Table[string, HttpCall]

  defaultlineHeightRatio* = 1.618.UICoord ##\
    ## see https://medium.com/@zkareemz/golden-ratio-62b3b6d4282a
  adjustTopTextFactor* = 1/16.0 # adjust top of text box for visual balance with descender's -- about 1/8 of fonts, so 1/2 that

  # global scroll bar settings
  scrollBarFill* = rgba(187, 187, 187, 162).color 
  scrollBarHighlight* = rgba(137, 137, 137, 162).color

  buttonPress*: ButtonView
  buttonDown*: ButtonView
  buttonRelease*: ButtonView


inputs.keyboardInput = proc (rune: Rune) =
    requestedFrame.inc
    # if keyboard.focusNode != nil:
    #   keyboard.state = KeyState.Press
    #   # currTextBox.typeCharacter(rune)
    # else:
    #   keyboard.state = KeyState.Press
    #   keyboard.keyString = rune.toUTF8()
    uiEvent.trigger()

proc newUId*(): NodeUID =
  # Returns next numerical unique id.
  inc lastUId
  when defined(js) or defined(StringUID):
    $lastUId
  else:
    NodeUID(lastUId)

proc refresh*() =
  ## Request the screen be redrawn
  requestedFrame = max(1, requestedFrame)

proc preNode(kind: NodeKind, id: Atom) =
  ## Process the start of the node.

  parent = nodeStack[^1]

  # TODO: maybe a better node differ?
  if parent.nodes.len <= parent.diffIndex:
    # Create Node.
    current = Node()
    current.uid = newUId()
    parent.nodes.add(current)
    refresh()
  else:
    # Reuse Node.
    current = parent.nodes[parent.diffIndex]
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

proc postNode() =
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
  preNode(kind, atom(id))
  setup
  inner
  postNode()

template node*(kind: NodeKind, id: static string, inner: untyped): untyped =
  ## Base template for node, frame, rectangle...
  preNode(kind, atom(id))
  inner
  postNode()


mouse = Mouse()
mouse.pos = vec2(0, 0)
