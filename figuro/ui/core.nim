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

  redrawNodes* {.runtimeVar.}: OrderedSet[Figuro]


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
  node.attrs = {}
  

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

template onSignal*[T](
    obj: T,
    signal: typed,
    cb: proc(obj: T) {.nimcall.},
) =
  proc handler(self: T) {.slot.} =
    `cb`(self)
  connect(node, signal, obj, handler, acceptVoidSlot=true)


template bindProp*[T](prop: Property[T]) =
  connect(prop, doChanged, Agent(node), Figuro.changed())

proc sibling*(self: Figuro, name: string): Option[Figuro] =
  ## finds first sibling with name
  for sibling in self.parent.children:
    if sibling.uid != self.uid and sibling.name == name:
      return some sibling
  return Figuro.none

template sibling*(name: string): Option[Figuro] =
  ## finds first sibling with name
  node.sibling(name)

proc clearDraw*(fig: Figuro) {.slot.} =
  fig.attrs.incl {preDrawReady, postDrawReady, contentsDrawReady}
  fig.userSetFields = {}
  fig.diffIndex = 0

proc handlePreDraw*(fig: Figuro) {.slot.} =
  if fig.preDraw != nil:
    fig.preDraw(fig)

proc handlePostDraw*(fig: Figuro) {.slot.} =
  if fig.postDraw != nil:
    fig.postDraw(fig)

proc connectDefaults*[T](node: T) {.slot.} =
  ## only activate these if custom ones have been provided 
  connect(node, doDraw, node, Figuro.clearDraw())
  connect(node, doDraw, node, Figuro.handlePreDraw())
  connect(node, doDraw, node, T.draw())
  connect(node, doDraw, node, Figuro.handlePostDraw())
  when T isnot BasicFiguro and compiles(SignalTypes.clicked(T)):
    connect(node, doClick, node, T.clicked())
  when T isnot BasicFiguro and compiles(SignalTypes.keyInput(T)):
    connect(node, doKeyInput, node, T.keyInput())
  when T isnot BasicFiguro and compiles(SignalTypes.keyPress(T)):
    connect(node, doKeyPress, node, T.keyPress())
  when T isnot BasicFiguro and compiles(SignalTypes.hover(T)):
    connect(node, doHover, node, T.hover())
  when T isnot BasicFiguro and compiles(SignalTypes.tick(T)):
    connect(root, doTick, node, T.tick(), acceptVoidSlot=true)

proc preNode*[T: Figuro](kind: NodeKind, id: string, node: var T, parent: Figuro) =
  ## Process the start of the node.
  mixin draw

  nodeDepth.inc()
  # echo nd(), "preNode:setup: id: ", id, " node: ", node.getId, " parent: ", parent.getId,
  #             " diffIndex: ", parent.diffIndex, " p:c:len: ", parent.children.len,
  #             " cattrs: ", if node.isNil: "{}" else: $node.attrs,
  #             " pattrs: ", if parent.isNil: "{}" else: $parent.attrs

  # TODO: maybe a better node differ?
  if parent.children.len <= parent.diffIndex:
    # Create Figuro.
    node = T()
    node.agentId = nextAgentId()
    node.uid = node.agentId
    node.parent = parent
    parent.children.add(node)
    # node.parent = parent
    echo nd(), "create new node: ", id, " new: ", node.getId, "/", node.parent.getId(), " n: ", node.name, " parent: ", parent.uid 
    refresh(node)
  else:
    # Reuse Figuro.
    # echo nd(), "checking reuse node"
    {.hint[CondTrue]:off.}
    if not (parent.children[parent.diffIndex] of T):
      # mismatch types, replace node
      node = T.new()
      # echo nd(), "create new replacement node: ", id, " new: ", node.uid, " parent: ", parent.uid
      parent.children[parent.diffIndex] = node
    else:
      # echo nd(), "reuse node: ", id, " new: ", node.getId, " parent: ", parent.uid
      node = T(parent.children[parent.diffIndex])
    {.hint[CondTrue]:on.}

    if resetNodes == 0 and
        node.nIndex == parent.diffIndex and
        kind == node.kind:
      # Same node.
      discard
    else:
      # Big change.
      node.nIndex = parent.diffIndex
      node.resetToDefault(kind)
      refresh(node)

  # echo nd(), "preNode: Start: ", id, " node: ", node.getId, " parent: ", parent.getId

  node.uid = node.agentId
  node.parent = parent
  let name = $(id)
  node.name.setLen(0)
  discard node.name.tryAdd(name)
  node.kind = kind
  node.highlight = parent.highlight
  node.transparency = parent.transparency
  node.zlevel = parent.zlevel
  node.theme = parent.theme

  node.listens.events = {}

  inc parent.diffIndex
  node.diffIndex = 0

  ## these define the default behaviors for Figuro widgets
  connectDefaults[T](node)

proc postNode*(node: var Figuro) =
  emit node.doDraw()

  node.removeExtraChildren()
  nodeDepth.dec()

import utils, macros, typetraits

template setupWidget(
    `widgetType`, `kind`, `id`, `hasCaptures`, `hasBinds`, `capturedVals`, `blk`
): auto =
  ## sets up a new instance of a widget
  block:
    when not compiles(node.typeof):
      {.warning: "missing `node` in current scope!".}
    let parent {.inject.}: Figuro = node
    var node {.inject.}: `widgetType` = nil
    preNode(`kind`, `id`, node, parent)
    wrapCaptures(`hasCaptures`, `capturedVals`):
      node.preDraw = proc (c: Figuro) =
        let node {.inject.} = `widgetType`(c)
        if preDrawReady in node.attrs:
          node.attrs.excl preDrawReady
          `blk`
    postNode(Figuro(node))
    when `hasBinds`:
      node

proc generateBodies*(widget, kind, gtype: NimNode,
                     wargs: WidgetArgs,
                     hasGeneric: bool,
                     ): NimNode {.compileTime.} =
  ## core macro helper that generates the drawing
  ## callbacks for widgets.
  let (id, _, bindsArg, capturedVals, blk) = wargs
  let hasCaptures = newLit(not capturedVals.isNil)
  let hasBinds = newLit(not bindsArg.isNil)
  let stateArg = gtype

  # echo "widget: ", widget.treeRepr
  # echo "stateArg: ", stateArg.treeRepr
  let widgetType =
    if not hasGeneric: quote do: `widget`
    else: quote do: `widget`[`stateArg`]
  # echo "widgetType: ", widgetType.treeRepr

  result = quote do:
    setupWidget(`widgetType`, `kind`, `id`,
                `hasCaptures`, `hasBinds`,
                `capturedVals`, `blk`)

macro widgetImpl(class, gclass: untyped, args: varargs[untyped]): auto =
  ## creates a widget block for a given widget
  let widget = class.getTypeInst()
  # echo "class: ", class.treeRepr, " ", class.getTypeInst().treeRepr
  # echo "gclass: ", gclass.treeRepr, " " # , gclass.getTypeImpl().treeRepr
  let wargs = args.parseWidgetArgs()
  var hasGeneric = true
  let (wtype, gtype) =
    if widget.kind == nnkBracketExpr:
      # echo "WBRACKET: "
      (widget[0].getTypeInst(), widget[1].getTypeInst())
    elif gclass != nil and gclass.getTypeInst().kind == nnkTupleConstr:
      # echo "GCLASS: "
      (widget.getTypeInst(), gclass)
    else:
      hasGeneric = false
      # echo "W NOGEN: "
      (widget.getTypeInst(), nil)
  # impl.expectKind(nnkTypeDef)
  # let hasGeneric = impl[1].len() > 0
  result = generateBodies(wtype, ident "nkRectangle", gtype,
                          wargs, hasGeneric)

template widget*[T, U](args: varargs[untyped]): auto =
  ## sets up a new instance of a widget of type `T`.
  ##
  ## The args can include:
  ## - `captures(...)` captures a variable similar to the stdlib `capture` macro
  ## - `state(U)` sets state type for Stateful widgets
  ##
  widgetImpl(T, U, args)

template new*[F](t: typedesc[F], args: varargs[untyped]): auto =
  when t.hasGenericTypes():
    widget[F, tuple[]](args)
  else:
    widget[F, void](args)

macro hasGenericTypes*(n: typed): bool =
  echo "hasGenericTypes: ", n.lispRepr
  var hasGenerics = true
  if n.kind == nnkBracketExpr:
    hasGenerics = true
  else:
    let impl = n.getImpl()
    hasGenerics = impl[1].len() > 0
  return newLit(hasGenerics)

template exportWidget*[T](name: untyped, class: typedesc[T]): auto =
  ## exports `class` as a template `name`,
  ## which in turn calls `widget[T](args): blk`
  ## 
  ## the exported widget template can take standard widget args
  ## that `widget` can.
  ##
  when class.hasGenericTypes():
    template `name`*(args: varargs[untyped]): auto =
      ## Instantiate a widget block for a given widget `T`
      ## creating a new Figuro node.
      ## 
      ## Behind the scenes this creates a new block
      ## with new `node` and `parent` variables.
      ## The `node` variable becomes the new widget
      ## instance.
      widget[T, tuple[]](args)
    template `name`*[U](args: varargs[untyped]): auto =
      ## Instantiate a widget block for a given widget `T`
      ## creating a new Figuro node.
      ## 
      ## Behind the scenes this creates a new block
      ## with new `node` and `parent` variables.
      ## The `node` variable becomes the new widget
      ## instance.
      widget[T, U](args)
  else:
    template `name`*(args: varargs[untyped]): auto =
      ## Instantiate a widget block for a given widget `T`
      ## creating a new Figuro node.
      ##
      ## Behind the scenes this creates a new block
      ## with new `node` and `parent` variables.
      ## The `node` variable becomes the new widget
      ## instance.
      widget[T, void](args)


{.hint[Name]:off.}
template TemplateContents*[T](fig: T): untyped =
  ## marks where the widget will callback for any `contents`
  ## useful
  if fig.contentsDraw != nil:
    fig.contentsDraw(node, Figuro(fig))
{.hint[Name]:on.}

macro contents*(args: varargs[untyped]): untyped =
  ## sets the contents of the node widget
  ## 
  let wargs = args.parseWidgetArgs()
  let (id, stateArg, bindsArg, capturedVals, blk) = wargs
  let hasCaptures = newLit(not capturedVals.isNil)

  result = quote do:
    block:
      when not compiles(node.typeof):
        {.error: "missing `var node` in node scope!".}
      let parentWidget = node
      wrapCaptures(`hasCaptures`, `capturedVals`):
        node.contentsDraw = proc (c, w: Figuro) =
          let node {.inject.} = c
          let widget {.inject.} = typeof(parentWidget)(w)
          if contentsDrawReady in widget.attrs:
            widget.attrs.excl contentsDrawReady
            `blk`
  # echo "contents: ", result.repr

macro expose*(args: untyped): untyped =
  if args.kind == nnkLetSection and 
      args[0].kind == nnkIdentDefs and
      args[0][2].kind in [nnkCall, nnkCommand]:
        result = args
        result[0][2].insert(2, nnkCall.newTree(ident "expose"))
        # echo "WID: args:post:\n", result.treeRepr
        # echo "WID: args:post:\n", result.repr
  else:
    result = args

macro nodeImpl*(kind: NodeKind, args: varargs[untyped]): untyped =
  ## Base template for node, frame, rectangle...
  let widget = ident("BasicFiguro")
  let wargs = args.parseWidgetArgs()
  result = widget.generateBodies(kind, nil, wargs, hasGeneric=false)

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

proc checkParent(node: Figuro) =
  if node.parent.isNil:
    raise newException(FiguroError, "cannot calculate exception: node: " & $node.getId & " parent: " & $node.parent.getId)

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
        UiAuto(_):
          when astToStr(f) in ["w"]:
            res = parentBox.f -  node.box.x
          elif astToStr(f) in ["h"]:
            res = parentBox.f -  node.box.y
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
      res
  
  let csValue = when astToStr(f) in ["w", "h"]: node.cxSize[dir] 
                else: node.cxOffset[dir]
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

template calcBasicConstraintPostImpl(
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
        UiContentMin(cmins):
          for n in node.children:
            when astToStr(f) in ["w"]:
              res = min(n.box.w + n.box.y, res)
            when astToStr(f) in ["h"]:
              res = min(n.box.h + n.box.y, res)
        UiContentMax(cmaxs):
          # res = cmaxs.UICoord
          for n in node.children:
            when astToStr(f) in ["w"]:
              res = max(n.box.w + n.box.x, res)
            when astToStr(f) in ["h"]:
              res = max(n.box.h + n.box.y, res)
        _:
          res = node.box.f
      res
  
  let csValue = when astToStr(f) in ["w", "h"]: node.cxSize[dir] 
                else: node.cxOffset[dir]
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
    UiEnd():
      discard

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
            {styleDim}, fgWhite, "node: ",
            resetStyle,
            fgWhite, $node.name, "[xy: ",
            fgGreen, $node.box.x.float.round(2),
              "x", $node.box.y.float.round(2),
            fgWhite, "; wh:",
            fgYellow, $node.box.w.float.round(2),
              "x", $node.box.h.float.round(2),
            fgWhite, "]")
  for c in node.children:
    printLayout(c, depth+2)

proc computeLayout*(node: Figuro, depth: int) =
  ## Computes constraints and auto-layout.

  # # simple constraints
  calcBasicConstraint(node, dcol, isXY=true)
  calcBasicConstraint(node, drow, isXY=true)
  calcBasicConstraint(node, dcol, isXY=false)
  calcBasicConstraint(node, drow, isXY=false)


  # css grid impl
  if not node.gridTemplate.isNil:
    # compute children first, then lay them out in grid
    for n in node.children:
      computeLayout(n, depth+1)

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
        calcBasicConstraint(c, dcol, isXY=false)
        calcBasicConstraint(c, drow, isXY=false)

  else:
    for n in node.children:
      computeLayout(n, depth+1)

    # update childrens
    for n in node.children:
      calcBasicConstraintPost(n, dcol, isXY=true)
      calcBasicConstraintPost(n, drow, isXY=true)
      calcBasicConstraintPost(n, dcol, isXY=false)
      calcBasicConstraintPost(n, drow, isXY=false)



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