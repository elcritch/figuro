import std/[tables, unicode, os, strformat]
import std/terminal
import std/times
import sigils

import basiccss
import commons
export commons
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

proc calculateMinOrMaxes(node: Figuro, fs: static string, doMax: static bool): UICoord =
  for n in node.children:
    when fs == "w":
      when doMax:
        result = max(n.box.w + n.box.y, result)
      else:
        result = min(n.box.w + n.box.y, result)
    elif fs == "h":
      when doMax:
        result = max(n.box.h + n.box.y, result)
      else:
        result = min(n.box.h + n.box.y, result)

template calcBasicConstraintImpl(node: Figuro, dir: static GridDir, f: untyped) =
  ## computes basic constraints for box'es when set
  ## this let's the use do things like set 90'pp (90 percent)
  ## of the box width post css grid or auto constraints layout
  let parentBox =
    if node.parent.isNil:
      node.frame[].windowSize
    else:
      node.parent[].box
  template calcBasic(val: untyped): untyped =
    block:
      var res: UICoord
      match val:
        UiAuto(_):
          when astToStr(f) in ["w"]:
            res = parentBox.f - node.box.x
          elif astToStr(f) in ["h"]:
            res = parentBox.f - node.box.y
        UiFixed(coord):
          res = coord.UICoord
        UiFrac(frac):
          node.checkParent()
          res = frac.UICoord * node.parent[].box.f
        UiPerc(perc):
          let ppval =
            when astToStr(f) == "x":
              parentBox.w
            elif astToStr(f) == "y":
              parentBox.h
            else:
              parentBox.f
          res = perc.UICoord / 100.0.UICoord * ppval
        UiContentMin(cmins):
          # res = cmins.UICoord
          # res = node.calculateMinOrMaxes(astToStr(f), doMax=false)
          when astToStr(f) in ["w"]:
            res = node.box.w
          elif astToStr(f) in ["h"]:
            res = node.box.h
        UiContentMax(cmaxs):
          # res = cmaxs.UICoord
          # res = node.calculateMinOrMaxes(astToStr(f), doMax=true)
          when astToStr(f) in ["w"]:
            res = node.box.w
          elif astToStr(f) in ["h"]:
            res = node.box.h
      res

  let csValue =
    when astToStr(f) in ["w", "h"]:
      node.cxSize[dir]
    else:
      node.cxOffset[dir]
  match csValue:
    UiNone:
      discard
    UiSum(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = lv + rv
    UiMin(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = min(lv, rv)
    UiMax(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = max(lv, rv)
    UiMinMax(ls, rs):
      discard
    UiValue(value):
      node.box.f = calcBasic(value)
    UiEnd:
      discard

proc calcBasicConstraint(node: Figuro, dir: static GridDir, isXY: static bool) =
  ## calcuate sizes of basic constraints per field x/y/w/h for each node
  when isXY == true and dir == dcol:
    calcBasicConstraintImpl(node, dir, x)
  elif isXY == true and dir == drow:
    calcBasicConstraintImpl(node, dir, y)
  # w & h need to run after x & y
  elif isXY == false and dir == dcol:
    calcBasicConstraintImpl(node, dir, w)
  elif isXY == false and dir == drow:
    calcBasicConstraintImpl(node, dir, h)

template calcBasicConstraintPostImpl(node: Figuro, dir: static GridDir, f: untyped) =
  ## computes basic constraints for box'es when set
  ## this let's the use do things like set 90'pp (90 percent)
  ## of the box width post css grid or auto constraints layout
  let parentBox =
    if node.parent.isNil:
      node.frame[].windowSize
    else:
      node.parent[].box
  template calcBasic(val: untyped): untyped =
    block:
      var res: UICoord
      match val:
        UiContentMin(cmins):
          res = node.calculateMinOrMaxes(astToStr(f), doMax=false)
        UiContentMax(cmaxs):
          res = node.calculateMinOrMaxes(astToStr(f), doMax=true)
          trace "CONTENT MAX: ", node = node.name, res = res, d = repr(dir), children = node.children.mapIt((it.name, it.box.w, it.box.h))
        _:
          res = node.box.f
      res

  let csValue =
    when astToStr(f) in ["w", "h"]:
      node.cxSize[dir]
    else:
      node.cxOffset[dir]
  
  trace "CONTENT csValue: ", node = node.name, d = repr(dir), csValue = csValue.repr
  match csValue:
    UiNone:
      discard
    UiSum(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = lv + rv
    UiMin(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = min(lv, rv)
    UiMax(ls, rs):
      let lv = ls.calcBasic()
      let rv = rs.calcBasic()
      node.box.f = max(lv, rv)
    UiMinMax(ls, rs):
      discard
    UiValue(value):
      node.box.f = calcBasic(value)
    UiEnd:
      discard
  trace "CONTENT csValue:POST ", node = node.name, w = node.box.w, h = node.box.h

proc calcBasicConstraintPost(node: Figuro, dir: static GridDir, isXY: static bool) =
  ## calcuate sizes of basic constraints per field x/y/w/h for each node
  when isXY == true and dir == dcol:
    calcBasicConstraintPostImpl(node, dir, x)
  elif isXY == true and dir == drow:
    calcBasicConstraintPostImpl(node, dir, y)
  # w & h need to run after x & y
  elif isXY == false and dir == dcol:
    calcBasicConstraintPostImpl(node, dir, w)
  elif isXY == false and dir == drow:
    calcBasicConstraintPostImpl(node, dir, h)

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

var sb: Figuro

proc computeLayout*(node: Figuro, depth: int) =
  ## Computes constraints and auto-layout.
  trace "computeLayout", name = node.name, box = node.box.wh.repr
  if node.name == "scrollBody":
    sb = node

  # # simple constraints
  calcBasicConstraint(node, dcol, isXY = true)
  calcBasicConstraint(node, drow, isXY = true)
  calcBasicConstraint(node, dcol, isXY = false)
  calcBasicConstraint(node, drow, isXY = false)

  # css grid impl
  if not node.gridTemplate.isNil:
    trace "computeLayout:gridTemplate", name = node.name, box = node.box.repr
    # compute children first, then lay them out in grid
    for n in node.children:
      computeLayout(n, depth + 1)

    # adjust box to not include offset in wh
    var box = node.box
    box.w = box.w - box.x
    box.h = box.h - box.y
    let res = node.gridTemplate.computeNodeLayout(box, node.children).Box
    # echo "gridTemplate: ", node.gridTemplate
    # echo "computeLayout:grid:\n\tnode.box: ", node.box, "\n\tbox: ", box, "\n\tres: ", res, "\n\toverflows: ", node.gridTemplate.overflowSizes
    node.box = res

    for n in node.children:
      for c in n.children:
        trace "computeLayout:gridTemplate:child:pre", name = c.name, box = c.box.wh.repr, sb = if sb != nil: sb.box.repr else: "", sbPtr = sb.unsafeWeakRef
        calcBasicConstraint(c, dcol, isXY = false)
        calcBasicConstraint(c, drow, isXY = false)
        trace "computeLayout:gridTemplate:child:post", name = c.name, box = c.box.wh.repr, sb = if sb != nil: sb.box.repr else: "", sbPtr = sb.unsafeWeakRef
    trace "computeLayout:gridTemplate:post", name = node.name, box = node.box.wh.repr, sb = if sb != nil: sb.box.repr else: "", sbPtr = sb.unsafeWeakRef
  else:
    for n in node.children:
      computeLayout(n, depth + 1)

    # update childrens
    for n in node.children:
      calcBasicConstraintPost(n, dcol, isXY = true)
      calcBasicConstraintPost(n, drow, isXY = true)
      calcBasicConstraintPost(n, dcol, isXY = false)
      calcBasicConstraintPost(n, drow, isXY = false)
      trace "calcBasicConstraintPost: ", n = n.name, w = n.box.w, h = n.box.h, sb = if sb != nil: sb.box.repr else: "", sbPtr = sb.unsafeWeakRef

  # debug "computeLayout:post: ",
  #   name = node.name, box = node.box.repr, prevSize = node.prevSize.repr, children = node.children.mapIt((it.name, it.box.repr))

  trace "computeLayout:post: ",
    name = node.name, box = node.box.repr, prevSize = node.prevSize.repr, sb = if sb != nil: sb.box.repr else: "", sbPtr = sb.unsafeWeakRef
  let currWh = node.box.wh
  # if currWh != node.prevSize:
  #   debug "computeLayout:post:changed: ",
  #     name = node.name, box = node.box.repr, prevSize = node.prevSize.repr
  #   emit node.doLayoutResize(node, (prev: node.prevSize, curr: currWh))
  #   node.prevSize = node.box.wh

proc computeLayout*(node: Figuro) =
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