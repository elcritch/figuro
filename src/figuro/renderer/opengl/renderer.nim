import std/[hashes, os, tables, times, monotimes, unicode, atomics]
export tables

from pixie import Image
import pkg/chroma
import pkg/sigils
import pkg/chronicles

import ../../common/rchannels
import ../../common/nodes/uinodes
import glcommons, glcontext, glutils

import std/locks

const FastShadows {.booldefine: "figuro.fastShadows".}: bool = false

type Renderer* = ref object of RootObj
  ctx*: Context
  duration*: Duration
  uxInputList*: RChan[AppInputs]
  rendInputList*: RChan[RenderCommands]
  frame*: WeakRef[AppFrame]
  lock*: Lock
  updated*: Atomic[bool]

  nodes*: Renders
  appWindow*: WindowInfo

method pollEvents*(r: Renderer) {.base.} = discard
method swapBuffers*(r: Renderer) {.base.} = discard
method setTitle*(r: Renderer, name: string) {.base.} = discard
method closeWindow*(r: Renderer) {.base.} = discard
method getScaleInfo*(r: Renderer): ScaleInfo {.base.} = discard
method getWindowInfo*(r: Renderer): WindowInfo {.base.} = discard
method configureWindowEvents*(renderer: Renderer) {.base.} = discard
method setClipboard*(r: Renderer, cb: ClipboardContents) {.base.} = discard
method getClipboard*(r: Renderer): ClipboardContents {.base.} = discard
method copyInputs*(r: Renderer): AppInputs {.base.} = discard

proc configureRenderer*(
    renderer: Renderer,
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
) =
  app.pixelScale = forcePixelScale
  renderer.nodes = Renders()
  renderer.frame = frame
  renderer.ctx = newContext(
    atlasSize = atlasSize,
    pixelate = false,
    pixelScale = app.pixelScale,
  )
  renderer.uxInputList = newRChan[AppInputs](5)
  renderer.rendInputList = newRChan[RenderCommands](5)
  renderer.lock.initLock()
  frame[].uxInputList = renderer.uxInputList
  frame[].rendInputList = renderer.rendInputList
  frame[].clipboards = newRChan[ClipboardContents](1)

proc renderDrawable*(ctx: Context, node: Node) =
  ## TODO: draw non-node stuff?
  for point in node.points:
    # ctx.linePolygon(node.poly, node.stroke.weight, node.stroke.color)
    let
      pos = point
      bx = node.box.atXY(pos.x, pos.y)
    ctx.fillRect(bx, node.fill)

proc renderText(ctx: Context, node: Node) {.forbids: [AppMainThreadEff].} =
  ## draw characters (glyphs)

  for glyph in node.textLayout.glyphs():
    if unicode.isWhiteSpace(glyph.rune):
      # Don't draw space, even if font has a char for it.
      # FIXME: use unicode 'is whitespace' ?
      continue

    let
      glyphId = glyph.hash()
      # is 0.84 (or 5/6) factor a constant for all fonts?
      # charPos = vec2(glyph.pos.x, glyph.pos.y - glyph.descent*0.84) # empirically determined
      charPos = vec2(glyph.pos.x, glyph.pos.y - glyph.descent*1.0) # empirically determined
    if glyphId notin ctx.entries:
      trace "no glyph in context: ", glyphId= glyphId, glyph= glyph.rune, glyphRepr= repr(glyph.rune)
      continue
    ctx.drawImage(glyphId, charPos, node.fill)

import macros except `$`

var postRenderImpl {.compileTime.}: seq[NimNode]

macro ifrender(check, code: untyped, post: untyped = nil) =
  ## check if code should be drawn
  result = newStmtList()
  let checkval = genSym(nskLet, "checkval")
  result.add quote do:
    # currLevel and `check`
    let `checkval` = `check`
    if `checkval`:
      `code`

  if post != nil:
    post.expectKind(nnkFinally)
    let postBlock = post[0]
    postRenderImpl.add quote do:
      if `checkval`:
        `postBlock`

macro postRender() =
  result = newStmtList()
  while postRenderImpl.len() > 0:
    result.add postRenderImpl.pop()

proc drawMasks(ctx: Context, node: Node) =
  if node.cornerRadius != [0'f32, 0'f32, 0'f32, 0'f32]:
    ctx.fillRoundedRect(
      rect(0, 0, node.screenBox.w, node.screenBox.h),
      rgba(255, 0, 0, 255).color,
      node.cornerRadius,
    )
  else:
    ctx.fillRect(
      rect(0, 0, node.screenBox.w, node.screenBox.h), rgba(255, 0, 0, 255).color
    )

proc renderDropShadows(ctx: Context, node: Node) =
  ## drawing shadows with 9-patch technique
  let shadow = node.shadow[DropShadow]
  if shadow.blur > 0.0:
    when FastShadows:
      ## should add a primitive to opengl.context to
      ## do this with pixie and 9-patch, but that's a headache
      let shadow = node.shadow[DropShadow]
      var color = shadow.color
      const N = 3
      color.a = color.a * 1.0/(N*N*N)
      let blurAmt = shadow.blur * shadow.spread / (12*N*N)
      for i in -N .. N:
        for j in -N .. N:
          let xblur: float32 = i.toFloat() * blurAmt
          let yblur: float32 = j.toFloat() * blurAmt
          let box = node.screenBox.atXY(x = shadow.x + xblur, y = shadow.y + yblur)
          ctx.fillRoundedRect(rect = box, color = color, radius = node.cornerRadius)
    else:
      ctx.fillRoundedRectWithShadow(
        rect = node.screenBox.atXY(0'f32, 0'f32),
        radii = node.cornerRadius,
        shadowX = shadow.x,
        shadowY = shadow.y,
        shadowBlur = shadow.blur,
        shadowSpread = shadow.spread.float32,
        shadowColor = shadow.color,
        innerShadow = false,
      )

proc renderInnerShadows(ctx: Context, node: Node) =
  ## drawing poor man's inner shadows
  ## this is even more incorrect than drop shadows, but it's something
  ## and I don't actually want to think today ;)
  when FastShadows:
    let shadow = node.shadow[InnerShadow]
    let n = shadow.blur.toInt
    var color = shadow.color
    color.a = 2*color.a/n.toFloat
    let blurAmt = shadow.blur / n.toFloat
    for i in 0 .. n:
      let blur: float32 = i.toFloat() * blurAmt
      var box = node.screenBox.atXY(x = 0'f32, y = 0'f32)
      # var box = node.screenBox.atXY(x = shadow.x, y = shadow.y)
      if shadow.x >= 0'f32:
        box.w += shadow.x
      else:
        box.x += shadow.x + blurAmt
      if shadow.y >= 0'f32:
        box.h += shadow.y
      else:
        box.y += shadow.y + blurAmt
      ctx.strokeRoundedRect(
        rect = box,
        color = color,
        weight = blur,
        radius = node.cornerRadius - blur,
      )
  else:
    let shadow = node.shadow[InnerShadow]
    var rect = node.screenBox.atXY(0'f32, 0'f32)
    ctx.fillRoundedRectWithShadow(
      rect = node.screenBox.atXY(0'f32, 0'f32),
      radii = node.cornerRadius,
      shadowX = shadow.x,
      shadowY = shadow.y,
      shadowBlur = shadow.blur,
      shadowSpread = shadow.spread.float32,
      shadowColor = shadow.color,
      innerShadow = true,
    )

proc renderBoxes(ctx: Context, node: Node) =
  ## drawing boxes for rectangles
  if node.fill.a > 0'f32:
    if node.cornerRadius != [0'f32, 0'f32, 0'f32, 0'f32]:
      discard
      ctx.fillRoundedRect(
        rect = node.screenBox.atXY(0'f32, 0'f32),
        color = node.fill,
        radii = node.cornerRadius,
        weight = node.stroke.weight,
      )
    else:
      ctx.fillRect(node.screenBox.atXY(0'f32, 0'f32), node.fill)

  if node.highlight.a > 0'f32:
    if node.cornerRadius != [0'f32, 0'f32, 0'f32, 0'f32]:
      ctx.fillRoundedRect(
        rect = node.screenBox.atXY(0'f32, 0'f32),
        color = node.highlight,
        radii = node.cornerRadius,
        weight = node.stroke.weight,
      )
    else:
      ctx.fillRect(node.screenBox.atXY(0'f32, 0'f32), node.highlight)

  if node.image.id.int != 0:
    let size = vec2(node.screenBox.w, node.screenBox.h)
    if ctx.cacheImage(node.image.name, node.image.id.Hash):
      ctx.drawImage(node.image.id.Hash, pos = vec2(0, 0), color = node.image.color, size = size)

  if node.stroke.color.a > 0 and node.stroke.weight > 0:
    ctx.fillRoundedRect(
      rect = node.screenBox.atXY(0'f32, 0'f32),
      color = node.stroke.color,
      radii = node.cornerRadius,
      weight = node.stroke.weight,
      doStroke = true,
    )

proc render(
    ctx: Context, nodes: seq[Node], nodeIdx, parentIdx: NodeIdx
) {.forbids: [AppMainThreadEff].} =
  template node(): auto =
    nodes[nodeIdx.int]

  template parent(): auto =
    nodes[parentIdx.int]

  ## Draws the node.
  ##
  ## This is the primary routine that handles setting up the OpenGL
  ## context that will get rendered. This doesn't trigger the actual
  ## OpenGL rendering, but configures the various shaders and elements.
  ##
  ## Note that visiable draw calls need to check they're on the current
  ## active ZLevel (z-index).
  if NfDisableRender in node.flags:
    return

  # setup the opengl context to match the current node size and position

  ctx.saveTransform()
  ctx.translate(node.screenBox.xy)

  # handle node rotation
  ifrender node.rotation != 0:
    ctx.translate(node.screenBox.wh / 2)
    ctx.rotate(node.rotation / 180 * PI)
    ctx.translate(-node.screenBox.wh / 2)

  ifrender node.kind == nkRectangle and node.shadow[DropShadow].blur > 0.0:
    ctx.renderDropShadows(node)

  # handle clipping children content based on this node
  ifrender NfClipContent in node.flags:
    ctx.beginMask()
    ctx.drawMasks(node)
    ctx.endMask()
  finally:
    ctx.popMask()

  ifrender true:
    if node.kind == nkText:
      ctx.renderText(node)
    elif node.kind == nkDrawable:
      ctx.renderDrawable(node)
    elif node.kind == nkRectangle:
      ctx.renderBoxes(node)

  ifrender node.kind == nkRectangle and node.shadow[InnerShadow].blur > 0.0:
    ctx.beginMask()
    ctx.drawMasks(node)
    ctx.endMask()
    ctx.renderInnerShadows(node)
    ctx.popMask()

  # restores the opengl context back to the parent node's (see above)
  ctx.restoreTransform()

  for childIdx in childIndex(nodes, nodeIdx):
    ctx.render(nodes, childIdx, nodeIdx)

  # finally blocks will be run here, in reverse order
  postRender()

proc renderRoot*(ctx: Context, nodes: var Renders) {.forbids: [AppMainThreadEff].} =
  # draw root for each level
  # currLevel = zidx
  var img: (Hash, Image)
  while glyphImageChan.tryRecv(img):
    # echo "img: ", img
    ctx.putImage(img[0], img[1])

  for zlvl, list in nodes.layers.pairs():
    for rootIdx in list.rootIds:
      ctx.render(list.nodes, rootIdx, -1.NodeIdx)

proc renderFrame*(renderer: Renderer) =
  let ctx: Context = renderer.ctx
  clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
  ctx.beginFrame(renderer.appWindow.box.wh.scaled())
  ctx.saveTransform()
  ctx.scale(ctx.pixelScale)

  # draw root
  ctx.renderRoot(renderer.nodes)

  ctx.restoreTransform()
  ctx.endFrame()

  when defined(testOneFrame):
    ## This is used for test only
    ## Take a screen shot of the first frame and exit.
    var img = takeScreenshot()
    img.writeFile("screenshot.png")
    quit()

proc renderAndSwap(renderer: Renderer) =
  ## Does drawing operations.

  timeIt(drawFrame):
    renderFrame(renderer)

  for error in glErrors():
    echo error

  timeIt(drawFrameSwap):
    renderer.swapBuffers()

proc pollAndRender*(renderer: Renderer, poll = true) =
  ## renders and draws a window given set of nodes passed
  ## in via the Renderer object

  if poll:
    renderer.pollEvents()

  var update = false
  var cmd: RenderCommands
  while renderer.rendInputList.tryRecv(cmd):
    match cmd:
      RenderUpdate(nlayers, rwindow):
        renderer.nodes = nlayers
        renderer.appWindow = rwindow
        update = true
      RenderQuit:
        echo "QUITTING"
        renderer.frame[].windowInfo.running = false
        app.running = false
        return
      RenderSetTitle(name):
        renderer.setTitle(name)
      RenderClipboardGet:
        let cb = renderer.getClipboard()
        renderer.frame[].clipboards.push(cb)
      RenderClipboard(cb):
        renderer.setClipboard(cb)

  if update:
    renderAndSwap(renderer)

proc runRendererLoop*(renderer: Renderer) =
  threadEffects:
    RenderThread
  while app.running:
    pollAndRender(renderer)

    os.sleep(renderer.duration.inMilliseconds)
  debug "Renderer loop exited"
  renderer.closeWindow()
  debug "Renderer window closed"
