import std/tables
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
    let totalOffset = node.offset + parent.totalOffset
    let screenBox = node.box + parent.screenBox + node.offset
    if screenBox != node.screenBox or totalOffset != node.totalOffset:
      # debug "computeScreenBox:changed: ", name = node.name, screenBox = screenBox, nodeScreenBox = node.screenBox
      emit node.doLayoutResize(node)
    node.screenBox = screenBox
    node.totalOffset = totalOffset

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
    "] {",
    fgWhite,
    "xy:",
    fgBlue,
    $node.screenBox.x.float.round(2),
    "x",
    $node.screenBox.y.float.round(2),
    fgWhite,
    "; wh:",
    fgBlue,
    $node.screenBox.w.float.round(2),
    "x",
    $node.screenBox.h.float.round(2),
    fgWhite,
    "}",
  )
  for c in node.children:
    printLayout(c, depth + 2)

# var sb: Figuro

template getParentBoxOrWindows*(node: Figuro): tuple[box, padding: Box] =
  if node.parent.isNil:
    (box: node.frame[].window.box, padding: uiBox(0,0,0,0))
  else:
    (box: node.parent[].box, padding: node.parent[].bpad)

proc computeLayouts*(node: Figuro) =
  # doAssert node.cxSize[drow] == csAuto() and node.cxSize[dcol] == csAuto(), "Your root widget must call `withRootWidget` in it's draw method to run correctly!"

  let cssValues = if node.frame[].theme.css.len > 0: node.frame[].theme.cssValues else: nil
  when defined(debugLayoutPre) or defined(figuroDebugLayoutPre):
    stdout.styledWriteLine(
      {styleDim}, fgWhite, "computeLayout:pre ", {styleDim}, fgGreen, ""
    )
    printLayout(node)
  computeLayout(node, cssValues)
  when defined(debugLayout) or defined(figuroDebugLayout):
    stdout.styledWriteLine(
      {styleDim}, fgWhite, "computeLayout:post ", {styleDim}, fgGreen, ""
    )
    printLayout(node)
    echo ""
