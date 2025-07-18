import std/[hashes, os, tables, times, monotimes, unicode, atomics]
export tables

from pixie import Image
import pkg/chroma
import pkg/sigils
import pkg/chronicles

import ../../common/rchannels
import ../../common/nodes/uinodes
import ../utils/glutils
import ../utils/baserenderer
import ../utils/drawshadows
import ../utils/drawboxes
import glcommons, glcontext

import std/locks

const FastShadows {.booldefine: "figuro.fastShadows".}: bool = false

type OpenGLRenderer* = ref object of Renderer
  ctx*: Context

proc newOpenGLRenderer*(
    window: RendererWindow,
    frame: WeakRef[AppFrame],
    atlasSize: int,
): OpenGLRenderer =
  result = OpenGLRenderer(window: window)
  configureBaseRenderer(result, frame, 1.0, atlasSize)
  result.ctx = newContext(
    atlasSize = atlasSize,
    pixelate = false,
    pixelScale = app.pixelScale,
  )

proc renderDrawable*(ctx: Context, node: Node) =
  ## TODO: draw non-node stuff?
  for point in node.points:
    # ctx.linePolygon(node.poly, node.stroke.weight, node.stroke.color)
    let
      pos = point
      bx = node.box.atXY(pos.x, pos.y)
    ctx.drawRect(bx, node.fill)

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
    ctx.drawRoundedRect(
      node.screenBox,
      rgba(255, 0, 0, 255).color,
      node.cornerRadius,
    )
  else:
    ctx.drawRect(
      node.screenBox, rgba(255, 0, 0, 255).color
    )

proc renderDropShadows(ctx: Context, node: Node) =
  ## drawing shadows with 9-patch technique
  let shadow = node.shadow[DropShadow]
  if shadow.blur <= 0.0 and shadow.spread <= 0.0:
    return

  when FastShadows:
    ## should add a primitive to opengl.context to
    ## do this with pixie and 9-patch, but that's a headache
    var color = shadow.color
    const N = 3
    color.a = color.a * 1.0/(N*N*N)
    let blurAmt = shadow.blur * shadow.spread / (12*N*N)
    for i in -N .. N:
      for j in -N .. N:
        let xblur: float32 = i.toFloat() * blurAmt
        let yblur: float32 = j.toFloat() * blurAmt
        let box = node.screenBox.atXY(x = shadow.x + xblur, y = shadow.y + yblur)
        ctx.drawRoundedRect(rect = box, color = color, radius = node.cornerRadius)
  else:
    ctx.fillRoundedRectWithShadowSdf(
      rect = node.screenBox,
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
  let shadow = node.shadow[InnerShadow]
  if shadow.blur <= 0.0 and shadow.spread <= 0.0:
    return

  when FastShadows:
    let n = shadow.blur.toInt
    var color = shadow.color
    color.a = 2*color.a/n.toFloat
    let blurAmt = shadow.blur / n.toFloat
    for i in 0 .. n:
      let blur: float32 = i.toFloat() * blurAmt
      var box = node.screenBox
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
    ctx.fillRoundedRectWithShadowSdf(
      rect = node.screenBox,
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
      ctx.drawRoundedRect(
        rect = node.screenBox,
        color = node.fill,
        radii = node.cornerRadius,
      )
    else:
      ctx.drawRect(node.screenBox, node.fill)

  if node.highlight.a > 0'f32:
    if node.cornerRadius != [0'f32, 0'f32, 0'f32, 0'f32]:
      ctx.drawRoundedRect(
        rect = node.screenBox,
        color = node.highlight,
        radii = node.cornerRadius,
      )
    else:
      ctx.drawRect(node.screenBox, node.highlight)

  if node.image.id.int != 0:
    let size = vec2(node.screenBox.w, node.screenBox.h)
    if ctx.cacheImage(node.image.name, node.image.id.Hash):
      ctx.drawImage(node.image.id.Hash, pos = node.screenBox.xy, color = node.image.color, size = size)

  if node.stroke.color.a > 0 and node.stroke.weight > 0:
    ctx.drawRoundedRect(
      rect = node.screenBox,
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

  # ctx.saveTransform()
  # ctx.translate(node.screenBox.xy)

  # handle node rotation
  ifrender node.rotation != 0:
    ctx.saveTransform()
    ctx.translate(node.screenBox.wh / 2)
    ctx.rotate(node.rotation / 180 * PI)
    ctx.translate(-node.screenBox.wh / 2)
  finally:
    ctx.restoreTransform()

  ifrender node.kind == nkRectangle:
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
      ctx.saveTransform()
      ctx.translate(node.screenBox.xy)
      ctx.renderText(node)
      ctx.restoreTransform()
    elif node.kind == nkDrawable:
      ctx.renderDrawable(node)
    elif node.kind == nkRectangle:
      ctx.renderBoxes(node)

  ifrender node.kind == nkRectangle:
    if NfClipContent notin node.flags:
      ctx.beginMask()
      ctx.drawMasks(node)
      ctx.endMask()
      ctx.renderInnerShadows(node)
      ctx.popMask()
    else:
      ctx.renderInnerShadows(node)

  # restores the opengl context back to the parent node's (see above)
  # ctx.restoreTransform()

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

proc renderFrame*(renderer: OpenGLRenderer) =
  let ctx: Context = renderer.ctx
  clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
  ctx.beginFrame(renderer.window.info.box.wh.scaled())
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

method renderAndSwap*(renderer: OpenGLRenderer) =
  ## Does drawing operations.

  timeIt(drawFrame):
    renderFrame(renderer)

  for error in glErrors():
    echo error

  timeIt(drawFrameSwap):
    renderer.window.swapBuffers()
