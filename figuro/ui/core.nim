import std/[tables, unicode, strformat, ]
import std/terminal
# import cssgrid

import commons
export commons

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var
  root* {.runtimeVar.}: Figuro
  # current* {.runtimeVar.}: Figuro
  # parent* {.runtimeVar, threadvar.}: Figuro

  redrawNodes* {.runtimeVar.}: OrderedSet[Figuro]

  nodeStack* {.runtimeVar.}: seq[Figuro]
  # gridStack*: seq[GridTemplate]

  scrollBox* {.runtimeVar.}: Box
  scrollBoxMega* {.runtimeVar.}: Box ## Scroll box is 500px bigger in y direction
  scrollBoxMini* {.runtimeVar.}: Box ## Scroll box is smaller by 100px useful for debugging

  numNodes* {.runtimeVar.}: int
  popupActive* {.runtimeVar.}: bool
  inPopup* {.runtimeVar.}: bool
  resetNodes* {.runtimeVar.}: int

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

var
  defaultTypeface* {.runtimeVar.} = internal.getTypeface("IBMPlexSans-Regular.ttf")
  defaultFont* {.runtimeVar.} = UiFont(typefaceId: defaultTypeface, size: 14'ui)

proc resetToDefault*(node: Figuro, kind: NodeKind) =
  ## Resets the node to default state.

  node.box = initBox(0,0,0,0)
  node.rotation = 0
  # node.screenBox = rect(0,0,0,0)
  # node.offset = vec2(0, 0)
  node.fill = clearColor
  node.transparency = 0
  node.stroke = Stroke(weight: 0, color: clearColor)
  # node.textStyle = TextStyle()
  # node.image = ImageStyle(name: "", color: whiteColor)
  node.cornerRadius = 0'ui
  # node.shadow = Shadow.none()
  node.diffIndex = 0
  node.zlevel = 0.ZLevel
  

var nodeDepth = 0
proc nd*(): string =
  for i in 0..nodeDepth:
    result &= "   "

proc setupRoot*(widget: Figuro) =
  if root == nil:
    raise newException(NilAccessDefect, "must set root")
  root.diffIndex = 0
  if root.theme.isNil:
    root.theme = Theme(font: defaultFont)

proc disable(fig: Figuro) =
  if not fig.isNil:
    fig.parent = nil
    fig.attrs.incl inactive
    for child in fig.children:
      disable(child)

proc removeExtraChildren*(node: Figuro) =
  ## Deal with removed nodes.
  if node.diffIndex == node.children.len:
    return
  echo nd(), "removeExtraChildren: ", node.getId, " parent: ", node.parent.getId
  for i in node.diffIndex..<node.children.len:
    disable(node.children[i])
  echo nd(), "Disable:setlen: ", node.getId, " diff: ", node.diffIndex
  node.children.setLen(node.diffIndex)

proc refresh*(node: Figuro) =
  ## Request the screen be redrawn
  if node == nil:
    return
  # app.requestedFrame.inc
  redrawNodes.incl(node)

proc changed*(self: Figuro) {.slot.} =
  refresh(self)

proc update*[T](self: Property[T], value: T) {.slot.} =
  if self.value != value:
    self.value = value
    emit self.doChanged()

proc update*[T](self: StatefulFiguro[T], value: T) {.slot.} =
  if self.state != value:
    self.state = value
    emit self.doChanged()

template onEvent*[T](signal: typed, obj: T,
                               cb: proc(obj: T) {.nimcall.}) =
  when signalName(signal) == "doClick":
    proc handler(counter: T, ek: EventKind, b: UiButtonView) {.slot.} =
      if ek == Enter: `cb`(counter)
    connect(current, signal, obj, handler)
  when signalName(signal) == "doButton":
    proc handler(counter: T) {.slot.} =
      `cb`(counter)
    connect(current, signal, obj, handler)


template bindProp*[T](prop: Property[T]) =
  connect(prop, doChanged, Agent(current), Figuro.changed())

proc sibling*(self: Figuro, name: string): Option[Figuro] =
  ## finds first sibling with name
  for sibling in self.parent.children:
    if sibling.uid != self.uid and sibling.name == name:
      return some sibling
  return Figuro.none

template sibling*(name: string): Option[Figuro] =
  ## finds first sibling with name
  current.sibling(name)

proc clearDraw*(fig: Figuro) {.slot.} =
  fig.attrs.incl {preDrawReady, postDrawReady, contentsDrawReady}
  fig.diffIndex = 0

proc handlePreDraw*(fig: Figuro) {.slot.} =
  if fig.preDraw != nil:
    fig.preDraw(fig)

proc handlePostDraw*(fig: Figuro) {.slot.} =
  if fig.postDraw != nil:
    fig.postDraw(fig)


proc preNode*[T: Figuro](kind: NodeKind, id: string, current: var T, parent: Figuro) =
  ## Process the start of the node.
  mixin draw

  nodeDepth.inc()
  # echo nd(), "preNode:setup: id: ", id, " current: ", current.getId, " parent: ", parent.getId,
  #             " diffIndex: ", parent.diffIndex, " p:c:len: ", parent.children.len,
  #             " cattrs: ", if current.isNil: "{}" else: $current.attrs,
  #             " pattrs: ", if parent.isNil: "{}" else: $parent.attrs

  # TODO: maybe a better node differ?
  if parent.children.len <= parent.diffIndex:
    # parent = nodeStack[^1]
    # Create Figuro.
    current = T()
    current.agentId = nextAgentId()
    current.uid = current.agentId
    current.parent = parent
    parent.children.add(current)
    # current.parent = parent
    echo nd(), "create new node: ", id, " new: ", current.getId, "/", current.parent.getId(), " n: ", current.name, " parent: ", parent.uid 
    refresh(current)
  else:
    # Reuse Figuro.
    # echo nd(), "checking reuse node"
    {.hint[CondTrue]:off.}
    if not (parent.children[parent.diffIndex] of T):
      # mismatch types, replace node
      current = T.new()
      # echo nd(), "create new replacement node: ", id, " new: ", current.uid, " parent: ", parent.uid
      parent.children[parent.diffIndex] = current
    else:
      # echo nd(), "reuse node: ", id, " new: ", current.getId, " parent: ", parent.uid
      current = T(parent.children[parent.diffIndex])
    {.hint[CondTrue]:on.}

    if resetNodes == 0 and
        current.nIndex == parent.diffIndex and
        kind == current.kind:
      # Same node.
      discard
    else:
      # Big change.
      current.nIndex = parent.diffIndex
      current.resetToDefault(kind)
      refresh(current)

  # echo nd(), "preNode: Start: ", id, " current: ", current.getId, " parent: ", parent.getId

  current.uid = current.agentId
  current.parent = parent
  let name = $(id)
  current.name.setLen(0)
  discard current.name.tryAdd(name)
  current.kind = kind
  current.highlight = parent.highlight
  current.transparency = parent.transparency
  current.zlevel = parent.zlevel
  current.theme = parent.theme

  current.listens.events = {}

  nodeStack.add(current)
  inc parent.diffIndex
  current.diffIndex = 0

  ## these define the default behaviors for Figuro widgets
  connect(current, doDraw, current, Figuro.clearDraw())
  connect(current, doDraw, current, Figuro.handlePreDraw())
  connect(current, doDraw, current, T.draw())
  connect(current, doDraw, current, Figuro.handlePostDraw())
  ## only activate these if custom ones have been provided 
  # static:
  #   echo "T is ", repr(typeof(T))
  #   echo "T compiles: SignalT: ", compiles(SignalTypes.clicked(T))
  #   echo "T compiles T.clicked(): ", compiles(T.clicked())
  when T isnot BasicFiguro and compiles(SignalTypes.clicked(T)):
    connect(current, doClick, current, T.clicked())
  when T isnot BasicFiguro and compiles(SignalTypes.keyInput(T)):
    connect(current, doKeyInput, current, T.keyInput())
  when T isnot BasicFiguro and compiles(SignalTypes.keyPress(T)):
    connect(current, doKeyPress, current, T.keyPress())
  when T isnot BasicFiguro and compiles(SignalTypes.hover(T)):
    connect(current, doHover, current, T.hover())

proc postNode*(current: var Figuro) =
  emit current.doDraw()

  current.removeExtraChildren()
  nodeDepth.dec()

import utils, macros

proc generateBodies*(widget, kind: NimNode,
                     wargs: WidgetArgs,
                     hasGeneric: bool): NimNode {.compileTime.} =
  ## core macro helper that generates the drawing
  ## callbacks for widgets.
  let (id, stateArg, bindsArg, capturedVals, blk) = wargs
  let hasCaptures = newLit(not capturedVals.isNil)
  let hasBinds = newLit(not bindsArg.isNil)
  let widgetId = ident( "widget" & id.strVal.capitalize )

  echo "BINDS: ", bindsArg.treeRepr
  let widgetType =
    if not hasGeneric: quote do: `widget`
    else: quote do: `widget`[`stateArg`]

  result = quote do:
    when `hasBinds`:
      var `bindsArg` {.inject.}: `widgetType`
    block:
      when not compiles(current.typeof):
        {.error: "missing `var current` in current scope!".}
      let parent {.inject.}: Figuro = current
      var current {.inject.}: `widgetType` = nil
      preNode(`kind`, `id`, current, parent)
      when `hasBinds`:
        `bindsArg` = current
      wrapCaptures(`hasCaptures`, `capturedVals`):
        current.preDraw = proc (c: Figuro) =
          let current {.inject.} = `widgetType`(c)
          let widget {.inject.} = `widgetType`(c)
          if preDrawReady in widget.attrs:
            widget.attrs.excl preDrawReady
            `blk`
      postNode(Figuro(current))

template exportWidget*[T](name: untyped, class: typedesc[T]) =
  ## exports a `class` as a widget by giving it a macro with `name`
  ## which handles parsing widget args like `state(type)` and
  ## `captures(...)`. It also generatres the proper pre- and
  ## post- callbacks that are called before and after `doDraw`, 
  ## respectively.
  ## 
  macro `name`*(args: varargs[untyped]) =
    let widget = class.getTypeInst()
    let wargs = args.parseWidgetArgs()
    let impl = widget.getImpl()
    impl.expectKind(nnkTypeDef)
    let hasGeneric = impl[1].len() > 0

    result = generateBodies(widget, ident "nkRectangle", wargs, hasGeneric)

{.hint[Name]:off.}
template TemplateContents*[T](fig: T): untyped =
  ## marks where the widget will callback for any `contents`
  ## useful
  if fig.contentsDraw != nil:
    fig.contentsDraw(current, Figuro(fig))
{.hint[Name]:on.}

macro contents*(args: varargs[untyped]): untyped =
  # echo "contents:\n", args.treeRepr
  let wargs = args.parseWidgetArgs()
  let (id, stateArg, bindsArg, capturedVals, blk) = wargs
  let hasCaptures = newLit(not capturedVals.isNil)
  # echo "id: ", id
  # echo "stateArg: ", stateArg.repr
  # echo "captured: ", capturedVals.repr
  # echo "blk: ", blk.repr

  result = quote do:
    block:
      when not compiles(current.typeof):
        {.error: "missing `var current` in current scope!".}
      let parentWidget = current
      wrapCaptures(`hasCaptures`, `capturedVals`):
        current.contentsDraw = proc (c, w: Figuro) =
          let current {.inject.} = c
          let widget {.inject.} = typeof(parentWidget)(w)
          if contentsDrawReady in widget.attrs:
            widget.attrs.excl contentsDrawReady
            `blk`
  # echo "contents: ", result.repr

macro node*(kind: NodeKind, args: varargs[untyped]): untyped =
  ## Base template for node, frame, rectangle...
  let widget = ident("BasicFiguro")
  let wargs = args.parseWidgetArgs()
  result = widget.generateBodies(kind, wargs, hasGeneric=false)

proc computeScreenBox*(parent, node: Figuro, depth: int = 0) =
  ## Setups screenBoxes for the whole tree.
  if parent == nil:
    # node.box.w = app.windowSize.x
    # node.box.h = app.windowSize.y
    node.screenBox = node.box
    node.totalOffset = node.offset
  else:
    node.screenBox = node.box + parent.screenBox
    node.totalOffset = node.offset + parent.totalOffset

  for n in node.children:
    computeScreenBox(node, n, depth + 1)


var gridChildren: seq[Figuro]

proc checkParent(node: Figuro) =
  if node.parent.isNil:
    raise newException(FiguroError, "cannot calculate exception: current: " & $node.getId & " parent: " & $node.parent.getId)

template calcBasicConstraintImpl(
    node: Figuro,
    dir: static GridDir,
    f: untyped
) =
  ## computes basic constraints for box'es when set
  ## this let's the use do things like set 90'pp (90 percent)
  ## of the box width post css grid or auto constraints layout
  let parentBox = if node.parent.isNil: app.windowSize
                  else: node.parent.box
  template calcBasic(val: untyped): untyped =
    block:
      var res: UICoord
      match val:
        UiFixed(coord):
          res = coord.UICoord
        UiFrac(frac):
          node.checkParent()
          res = frac.UICoord * node.parent.box.f
        UiPerc(perc):
          let ppval = when astToStr(f) == "x": parentBox.w
                      elif astToStr(f) == "y": parentBox.h
                      else: parentBox.f
          res = perc.UICoord / 100.0.UICoord * ppval
        UiContentMin(cmins):
          res = cmins.UICoord
        UiContentMax(cmaxs):
          res = cmaxs.UICoord
        UiAuto(_):
          when astToStr(f) in ["w", "h"]:
            node.checkParent()
            node.box.f = node.parent.box.f
          else:
            discard
      res
  
  let csValue = when astToStr(f) in ["w", "h"]: node.cxSize[dir] 
                else: node.cxOffset[dir]
  match csValue:
    UiNone:
      if not node.parent.isNil:
        when astToStr(f) in ["w"]:
          node.box.f = parentBox.f - parentBox.x - node.box.x
        elif astToStr(f) in ["h"]:
          node.box.f = parentBox.f - parentBox.y - node.box.y
        else:
          discard
      else:
        when astToStr(f) in ["w"]:
          node.box.f = parentBox.f - node.box.x
        elif astToStr(f) in ["h"]:
          node.box.f = parentBox.f - node.box.y
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
    UiEnd():
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

proc computeLayout*(node: Figuro, depth: int) =
  ## Computes constraints and auto-layout.
  
  # # simple constraints
  # if node.gridItem.isNil and node.parent != nil:
    # assert node.parent != nil, "check parent isn't nil: " & $node.parent.getId & " curr: " & $node.getId
  calcBasicConstraint(node, dcol, isXY=true)
  calcBasicConstraint(node, drow, isXY=true)
  calcBasicConstraint(node, dcol, isXY=false)
  calcBasicConstraint(node, drow, isXY=false)

  # css grid impl
  if not node.gridTemplate.isNil:
    # echo "calc grid!"
    
    gridChildren.setLen(0)
    for n in node.children:
      gridChildren.add(n)
    # adjust box to not include offset in wh
    var box = node.box
    box.w = box.w - box.x
    box.h = box.h - box.y
    node.box = node.gridTemplate.computeNodeLayout(box, gridChildren).Box

    for n in node.children:
      computeLayout(n, depth+1)

    return

  for n in node.children:
    computeLayout(n, depth+1)

proc printLayout*(node: Figuro, depth = 0) =
  stdout.styledWriteLine(" ".repeat(depth),
                          {styleDim}, fgWhite, "node: ",
                          resetStyle,
                          fgWhite, $node.name, "[xy: ",
                          fgGreen, $node.box.x, "x", $node.box.y,
                          fgWhite, "; wh:",
                          fgYellow, $node.box.w, "x", $node.box.h,
                          fgWhite, "]")
  for c in node.children:
    printLayout(c, depth+2)

proc computeLayout*(node: Figuro) =
  when defined(debugLayout) or defined(figuroDebugLayout):
    stdout.styledWriteLine({styleDim}, fgWhite, "computeLayout:pre ",
                            {styleDim}, fgGreen, "")
    printLayout(node)
  computeLayout(node, 0)
  when defined(debugLayout) or defined(figuroDebugLayout):
    stdout.styledWriteLine({styleDim}, fgWhite, "computeLayout:post ",
                            {styleDim}, fgGreen, "")
    printLayout(node)
    echo ""