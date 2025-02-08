import std/[tables, unicode, os, strformat]
import std/terminal
import std/times
import pkg/chronicles

import sigils/reactive

# import basiccss
import ../commons
import ../common/system
export commons
export system
export reactive

import csstheme

when defined(nimscript):
  {.pragma: runtimeVar, compileTime.}
else:
  {.pragma: runtimeVar, global.}

var
  scrollBox* {.runtimeVar.}: Box
  scrollBoxMega* {.runtimeVar.}: Box ## Scroll box is 500px bigger in y direction
  scrollBoxMini* {.runtimeVar.}: Box
    ## Scroll box is smaller by 100px useful for debugging

  numNodes* {.runtimeVar.}: int
  popupActive* {.runtimeVar.}: bool
  inPopup* {.runtimeVar.}: bool
  resetNodes* {.runtimeVar.}: int

  # Used to check for duplicate ID paths.
  pathChecker* {.runtimeVar.}: Table[string, bool]

  computeTextLayout* {.runtimeVar.}: proc(node: Figuro)

  nodeLookup* {.runtimeVar.}: Table[string, Figuro]

  defaultlineHeightRatio* {.runtimeVar.} = 1.618.UiScalar
    ##\
    ## see https://medium.com/@zkareemz/golden-ratio-62b3b6d4282a
  adjustTopTextFactor* {.runtimeVar.} = 1 / 16.0
    # adjust top of text box for visual balance with descender's -- about 1/8 of fonts, so 1/2 that

  # global scroll bar settings
  scrollBarFill* {.runtimeVar.} = rgba(187, 187, 187, 162).color
  scrollBarHighlight* {.runtimeVar.} = rgba(137, 137, 137, 162).color

const DefTypefaceName* = "IBMPlexSans-Regular.ttf"
const DefTypefaceRaw* = block:
    let path = DataDirPath.string / DefTypefaceName
    let data = readfile(path)
    data

static:
  echo "DefTypefaceRaw: ", DefTypefaceRaw.len

var
  defaultTypeface* {.runtimeVar.} = getTypeface(DefTypefaceName, DefTypefaceRaw, TTF)
  defaultFont* {.runtimeVar.} = UiFont(typefaceId: defaultTypeface, size: 14'ui)

proc setSize*(frame: AppFrame, size: (UiScalar, UiScalar)) =
  frame.windowSize.w = size[0]
  frame.windowSize.h = size[1]
  frame.windowRawSize = frame.windowSize.wh.scaled()
  # echo "setSize: ", frame.windowSize
  # echo "setSize: ", frame.windowRawSize

proc resetToDefault*(node: Figuro, kind: NodeKind) =
  ## Resets the node to default state.

  node.box = initBox(0, 0, 0, 0)
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
  for i in 0 .. nodeDepth:
    result &= "   "

proc disable(fig: Figuro) =
  if not fig.isNil:
    fig.parent.pt = nil
    fig.attrs.incl inactive
    for child in fig.children:
      disable(child)

proc removeExtraChildren*(node: Figuro) =
  ## Deal with removed nodes.
  if node.diffIndex == node.children.len:
    return
  echo nd(), "removeExtraChildren: ", node.getId, " parent: ", node.parent.getId
  for i in node.diffIndex ..< node.children.len:
    disable(node.children[i])
  echo nd(), "Disable:setlen: ", node.getId, " diff: ", node.diffIndex
  node.children.setLen(node.diffIndex)

proc refresh*(node: Figuro) {.slot.} =
  ## Request that the node and it's children be redrawn
  # echo "refresh: ", node.name, " :: ", getStackTrace()
  if node == nil:
    return
  # app.requestedFrame.inc
  assert not node.frame.isNil
  node.frame[].redrawNodes.incl(node)
  when defined(figuroDebugRefresh):
    echo "REFRESH: ", getStackTrace()

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

# template unBindSigilEvents*(blk: untyped): auto =
#   static: enableSigilBinding.add false
#   `blk`
#   static: discard enableSigilBinding.pop()

proc signalTrigger*[T](self: T, node: Figuro, signal: string) {.signal.}

proc forward(node: Figuro) {.slot.} =
  emit node.signalTrigger(node, "")

# template onSignal*[T](signal: untyped, obj: T, blk: untyped) =
#   proc handler(arg: typeof(`obj`)) {.slot.} =
#     let `obj` {.inject, used.} = arg
#     unBindSigilEvents:
#       `blk`
#   connect(node, signalTrigger, `obj`, handler, acceptVoidSlot = true)
#   connect(node, `signal`, node, Figuro.forward(), acceptVoidSlot = true)

import macros

proc getParams(doBody: NimNode): (NimNode, NimNode, NimNode) =
  echo "getParam: ", doBody.treeRepr
  if doBody.kind != nnkDo:
    error("Must provide a do body with 1 argument", doBody)
  let params = doBody[3]
  let target = params[1][0]
  let body = doBody[^1]
  return (target, params, body)

macro onSignal*(signal: untyped, blk: untyped) =
  let (target, params, body) =  getParams(blk)
  let args = repr(params)
  result = quote do:
    let `target` = `target`
    proc handler() {.slot.} =
      unBindSigilEvents:
        `body`
    when not compiles(handler(`target`)):
      {.error: "mismatched do block argument: `" & `args` &
               "`; expected `onSignal(" & astToStr(`signal`) & ") do (" &
               astToStr(`target`) & ": " & $(typeof(`target`)) & ")`".}
    connect(this, signalTrigger, `target`, handler, acceptVoidSlot = true)
    connect(this, `signal`, this, Figuro.forward(), acceptVoidSlot = true)
  result[1].params = params
  # echo "result: ", result.treeRepr

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
  fig.contents.setLen(0)

proc handlePreDraw*(fig: Figuro) {.slot.} =
  if fig.preDraw != nil and preDrawReady in fig.attrs:
    fig.preDraw(fig)

proc handleContents*(fig: Figuro) {.slot.} =
  for content in fig.contents:
    content.childInit(fig, content.name, content.childPreDraw)

proc handlePostDraw*(fig: Figuro) {.slot.} =
  if fig.postDraw != nil:
    fig.postDraw(fig)

proc handleTheme*(fig: Figuro) {.slot.} =
  fig.applyThemeRules()

template connectDefaults*[T](node: T) =
  ## connect default UI signals
  connect(node, doDraw, node, Figuro.clearDraw())
  connect(node, doDraw, node, Figuro.handlePreDraw())
  connect(node, doDraw, node, T.draw())
  connect(node, doDraw, node, T.handleContents())
  connect(node, doDraw, node, Figuro.handlePostDraw())
  connect(node, doDraw, node, Figuro.handleTheme())
  # only activate these if custom ones have been provided 

  when T isnot BasicFiguro:
    when compiles(SignalTypes.initialize(T)):
      connect(node, doInitialize, node, T.initialize())
    when compiles(SignalTypes.clicked(T)):
      connect(node, doMouseClick, node, T.clicked())
    when compiles(SignalTypes.dragged(T)):
      connect(node, doDrag, node, T.dragged())
    when compiles(SignalTypes.keyInput(T)):
      connect(node, doKeyInput, node, T.keyInput())
    when compiles(SignalTypes.keyPress(T)):
      connect(node, doKeyPress, node, T.keyPress())
    when compiles(SignalTypes.hover(T)):
      connect(node, doHover, node, T.hover())
    when compiles(SignalTypes.tick(T)):
      connect(node, doTick, node, T.tick(), acceptVoidSlot = true)

proc newAppFrame*[T](root: T, size: (UiScalar, UiScalar), style = DecoratedResizable): AppFrame =
  mixin draw
  if root == nil:
    raise newException(NilAccessDefect, "must set root")
  echo "app frame"
  connectDefaults[T](root)

  root.diffIndex = 0
  let frame = AppFrame(root: root)
  root.frame = frame.unsafeWeakRef()
  if frame.theme.isNil:
    frame.theme = Theme(font: defaultFont)
  frame.setSize(size)
  frame.windowStyle = style
  refresh(root)
  return frame

var lastModificationTime: times.Time

proc themePath*(): string =
  result = "theme.css".absolutePath()

proc loadTheme*(defaultTheme: string = themePath()): seq[CssBlock] =
  # let defaultTheme = themePath()
  if defaultTheme.fileExists():
    let ts = getLastModificationTime(defaultTheme)
    if ts > lastModificationTime:
      lastModificationTime = ts
      notice "Loading CSS file", cssFile = defaultTheme
      let parser = newCssParser(Path(defaultTheme))
      let cssTheme = parse(parser)
      result = cssTheme
      notice "Loaded CSS file", cssFile = defaultTheme

proc preNode*[T: Figuro](kind: NodeKind, nid: string, node: var T, parent: Figuro) =
  ## Process the start of the node.

  nodeDepth.inc()
  trace "preNode:setup", nd= nd(), id= nid, node= node.getId, parent = parent.getId,
              diffIndex = parent.diffIndex, parentChilds = parent.children.len,
              cattrs = if node.isNil: "{}" else: $node.attrs,
              pattrs = if parent.isNil: "{}" else: $parent.attrs

  # TODO: maybe a better node differ?
  template createNewNode[T](tp: typedesc[T], node: untyped) =
    node = T()
    node.uid = nextFiguroId()
    node.parent = parent.unsafeWeakRef()
    node.frame = parent.frame
    node.widgetName = repr(T).split('[')[0]
    node.name = nid

  if parent.children.len <= parent.diffIndex:
    # Create Figuro.
    createNewNode(T, node)
    parent.children.add(node)
    trace "preNode:create:", nd = nd(),
      name= node.name, widget= node.widgetName,
      new = fmt"{$node.getId}/{node.parent.getId()}", n= node.name, parent= parent.uid
    # refresh(node)
  elif not (parent.children[parent.diffIndex] of T):
    # mismatched types, replace node
    createNewNode(T, node)
    # echo nd(), "create new replacement node: ", id, " new: ", node.uid, " parent: ", parent.uid
    parent.children[parent.diffIndex] = node
  else:
    # Reuse Figuro.
    # echo nd(), "checking reuse node"
    # echo nd(), "reuse node: ", id, " new: ", node.getId, " parent: ", parent.uid
    node = T(parent.children[parent.diffIndex])

    if resetNodes == 0 and node.nIndex == parent.diffIndex and kind == node.kind:
      # Same node.
      discard
    else:
      # Big change.
      node.nIndex = parent.diffIndex
      node.resetToDefault(kind)
      node.name = nid

  # echo nd(), "preNode: Start: ", id, " node: ", node.getId, " parent: ", parent.getId

  node.kind = kind
  node.highlight = parent.highlight
  node.transparency = parent.transparency
  node.zlevel = parent.zlevel
  # node.theme = parent.theme

  node.listens.events = {}

  inc parent.diffIndex
  node.diffIndex = 0

  ## these define the default behaviors for Figuro widgets
  connectDefaults[T](node)

proc postNode*(node: var Figuro) =
  if initialized notin node.attrs:
    emit node.doInitialize()
    node.attrs.incl initialized
  emit node.doDraw()

  node.removeExtraChildren()
  nodeDepth.dec()

import utils, macros, typetraits

template nodeInitImpl*[T](kind, parent, name, preDraw: typed) =
  var node: `T` = nil
  preNode(kind, name, node, parent)
  node.preDraw = preDraw
  postNode(Figuro(node))

proc nodeInitRect*[T](parent: Figuro, name: string, preDraw: proc(current: Figuro) {.closure.}) {.nimcall.} =
  ## callback proc to initialized a new node, or re-use and existing node
  nodeInitImpl[T](nkRectangle, parent, name, predraw)
proc nodeInitText*[T](parent: Figuro, name: string, preDraw: proc(current: Figuro) {.closure.}) {.nimcall.} =
  ## callback proc to initialized a new node, or re-use and existing node
  nodeInitImpl[T](nkText, parent, name, predraw)

proc widgetRegisterImpl*[T](nkind: static NodeKind, nn: string, node: Figuro, callback: proc(c: Figuro) {.closure.}) =
  ## sets up a new instance of a widget of type `T`.
  ##
  
  let fc = FiguroContent(
    name: $(nn),
    childInit: when nkind == nkText: nodeInitText[T] else: nodeInitRect[T],
    childPreDraw: callback,
  )
  node.contents.add(fc)

template widgetRegister*[T](nkind: static NodeKind, nn: string | static string, blk: untyped) =
  ## sets up a new instance of a widget of type `T`.
  ##
  when not compiles(this.typeof):
    {.error: "No `this` variable found in the current scope! Figuro's APIs rely on an having a `this` variable referring to the current widget or node. Check that you have `withWidget` or `withRootWidget` at the top of your widget draw slots.".}
  
  let childPreDraw = proc(c: Figuro) =
      # echo "widgt PRE-DRAW INIT: ", nm
      let this {.inject.} = ## implicit variable in each widget block that references the current widget
        `T`(c)
      `blk`
  widgetRegisterImpl[T](nkind, nn, this, childPreDraw)

# template new*(t: typedesc[Text], name: untyped, blk: untyped): auto =
#   widgetRegister[t](nkText, name, blk)

template new*(tp: typedesc, name: string, blk: untyped) =
  ## Sets up a new widget instance by calling widgetRegister
  ## 
  ## Accepts types with incomplete generics and fills
  ## them in `tuple[]` for missing generics in the widget type.
  ## 
  ## E.g. if you have a `Button[T]` and you call
  ## `Button.new` this template will change it to
  ## `Button[tuple[]].new`.
  ## 
  when arity(tp) in [0, 1]:
    # non-generic type, note that arity(ref object) == 1
    widgetRegister[tp](nkRectangle, name, blk)
  elif arity(tp) == stripGenericParams(tp).typeof().arity():
    # partial generics, these are generics that aren't specified
    when stripGenericParams(tp).typeof().arity() == 2:
      # partial generic, we'll provide empty tuple
      widgetRegister[tp[tuple[]]](nkRectangle, name, blk)
    else:
      {.error: "only 1 generic params or less is supported".}
  else:
    # fully typed generics
    widgetRegister[tp](nkRectangle, name, blk)

{.hint[Name]: off.}
template WidgetContents*(): untyped =
  ## marks where the widget will put any child `content`
  ## which is comparable to html template and child slots.
  # if fig.contentsDraw != nil:
  #   fig.contentsDraw(node, Figuro(fig))
  for content in widgetContents:
    content.childInit(this, content.name, content.childPreDraw)
{.hint[Name]: on.}

template `as`*[T: ref](tp: typedesc[T], name: string, blk) =
  ## Alternate name for `new` widgets (experimental)
  ## 
  ## So `Widget.new "myFoo": ...` becomes `Widget as "myFoo": ...`
  ## 
  ## To be read like `Widget as a node with id and code block xyz`
  ## 

  new(tp, name, blk)

proc recompute*(obj: Figuro, attrs: set[SigilAttributes]) {.slot.} =
  refresh(obj)

template withWidget*(self, blk: untyped) =
  ## sets up a draw slot for working with Figuro nodes
  let this {.inject.} = self
  let widgetContents {.inject.} = move self.contents
  self.contents.setLen(0)

  bindSigilEvents(this):
    `blk`

template withRootWidget*(self, blk: untyped) =
  ## sets up a draw slot for working with Figuro nodes
  let this {.inject.} = self
  let widgetContents {.inject.} = move self.contents
  self.contents.setLen(0)

  Rectangle.new "main":
    bindSigilEvents(this):
      `blk`

