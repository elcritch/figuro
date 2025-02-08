import std/[tables, unicode, os, strformat]
import std/terminal
import std/times
import sigils

import ../commons
import pkg/chronicles

proc computeScreenBox*(parent, node: Figuro, depth: int = 0) =
  ## Setups screenBoxes for the whole tree.
  if parent == nil:
    node.screenBox = node.box
    node.totalOffset = node.offset
  else:
    node.screenBox = node.box + parent.screenBox
    node.totalOffset = node.offset + parent.totalOffset

  for n in node.children:
    computeScreenBox(node, n, depth + 1)

proc checkParent(node: Figuro) =
  if node.parent.isNil:
    raise newException(
      FiguroError,
      "cannot calculate exception: node: " & $node.getId & " parent: " &
        $node.parent.getId,
    )


proc printLayout*(node: Figuro, depth = 0) =
  stdout.styledWriteLine(
    " ".repeat(depth),
    {styleDim},
    fgWhite,
    "node: ",
    resetStyle,
    fgWhite,
    $node.name,
    " [xy: ",
    fgGreen,
    $node.box.x.float.round(2),
    "x",
    $node.box.y.float.round(2),
    fgWhite,
    "; wh:",
    fgYellow,
    $node.box.w.float.round(2),
    "x",
    $node.box.h.float.round(2),
    fgWhite,
    "]",
  )
  for c in node.children:
    printLayout(c, depth + 2)

# var sb: Figuro

template getParentBoxOrWindows*(node: Figuro): Box =
  if node.parent.isNil:
    node.frame[].windowSize
  else:
    node.parent[].box

proc computeLayouts*(node: Figuro) =
  when defined(debugLayout) or defined(figuroDebugLayout):
    stdout.styledWriteLine(
      {styleDim}, fgWhite, "computeLayout:pre ", {styleDim}, fgGreen, ""
    )
    printLayout(node)
  computeLayout(node, 0)
  when defined(debugLayout) or defined(figuroDebugLayout):
    stdout.styledWriteLine(
      {styleDim}, fgWhite, "computeLayout:post ", {styleDim}, fgGreen, ""
    )
    printLayout(node)
    echo ""