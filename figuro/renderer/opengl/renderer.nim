import std/[hashes, os, strformat, tables, times, unicode]

import pkg/chroma
import pkg/windy
import pkg/opengl
from pixie import Image

import window

import commons, fontutils, context, formatflippy, utils

export tables
export getTypeface, getTypeset

type
  Renderer* = ref object
    ctx*: Context
    window*: Window
    nodes*: RenderNodes
    uxInputList*: Chan[AppInputs]
    chan*: Chan[RenderNodes]
    frame*: AppFrame

proc newRenderer*(
    frame: AppFrame,
    window: Window,
    pixelate: bool,
    forcePixelScale: float32,
    atlasSize: int
): Renderer =
  app.pixelScale = forcePixelScale
  let renderer = Renderer(window: window)
  startOpenGL(frame, window, openglVersion)
  renderer.frame = frame
  renderer.ctx = newContext(atlasSize = atlasSize,
                    pixelate = pixelate,
                    pixelScale = app.pixelScale)
  renderer.chan = newChan[RenderNodes]()
  frame.uxInputList = renderer.uxInputList
  return renderer

proc renderDrawable*(ctx: Context, node: Node) =
  # ctx: Context, poly: seq[Vec2], weight: float32, color: Color
  for point in node.points:
    # ctx.linePolygon(node.poly, node.stroke.weight, node.stroke.color)
    let
      pos = point
      bx = node.box.atXY(pos.x, pos.y)
    ctx.fillRect(bx, node.fill)

proc renderText(ctx: Context, node: Node) {.forbids: [MainThreadEff].} =
  # draw characters
  # if node.textLayout == nil:
    # return

  for glyph in node.textLayout.glyphs():

    if unicode.isWhiteSpace(glyph.rune):
      # Don't draw space, even if font has a char for it.
      # FIXME: use unicode 'is whitespace' ?
      continue

    let
      glyphId = glyph.hash()
      charPos = vec2(glyph.pos.x ,
                      glyph.pos.y - glyph.descent)
    if glyphId notin ctx.entries:
      echo "no glyph in context: ", glyphId, " glyph: `", glyph.rune, "`", " (", repr(glyph.rune), ")"
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
  if node.cornerRadius != 0:
    ctx.fillRoundedRect(rect(
      0, 0,
      node.screenBox.w, node.screenBox.h
    ), rgba(255, 0, 0, 255).color, node.cornerRadius)
  else:
    ctx.fillRect(rect(
      0, 0,
      node.screenBox.w, node.screenBox.h
    ), rgba(255, 0, 0, 255).color)

proc renderShadows(ctx: Context, node: Node) =
  ## drawing shadows
  let shadow = node.shadow.get()
  let blurAmt = shadow.blur / 7.0
  for i in 0..6:
    let blurs: float32 = i.toFloat() * blurAmt
    let box = node.screenBox.atXY(x = shadow.x + blurs,
                                  y = shadow.y + blurs)
    ctx.fillRoundedRect(rect = box,
                        color = shadow.color,
                        radius = node.cornerRadius)

proc renderBoxes(ctx: Context, node: Node) =
  ## drawing boxes for rectangles
  if node.fill.a > 0'f32:
    if node.cornerRadius > 0:
      ctx.fillRoundedRect(rect = node.screenBox.atXY(0'f32, 0'f32),
                          color = node.fill,
                          radius = node.cornerRadius)
    else:
      ctx.fillRect(node.screenBox.atXY(0'f32, 0'f32), node.fill)

  if node.highlight.a > 0'f32:
    if node.cornerRadius > 0:
      ctx.fillRoundedRect(rect = node.screenBox.atXY(0'f32, 0'f32),
                          color = node.highlight,
                          radius = node.cornerRadius)
    else:
      ctx.fillRect(node.screenBox.atXY(0'f32, 0'f32), node.highlight)

  if node.kind == nkImage and node.image.name != "":
    let path = dataDir / node.image.name
    let size = vec2(node.screenBox.w, node.screenBox.h)
    ctx.drawImage(path,
                  pos = vec2(0, 0),
                  color = node.image.color,
                  size = size)
  
  if node.stroke.color.a > 0 and node.stroke.weight > 0:
    ctx.strokeRoundedRect(rect = node.screenBox.atXY(0'f32, 0'f32),
                          color = node.stroke.color,
                          weight = node.stroke.weight,
                          radius = node.cornerRadius)


proc render(ctx: Context, nodes: seq[Node], nodeIdx, parentIdx: NodeIdx) {.forbids: [MainThreadEff].} =

  template node(): auto = nodes[nodeIdx.int]
  template parent(): auto = nodes[parentIdx.int]

  # echo "draw:idx: ", nodeIdx, " parent: ", parentIdx
  # print node.uid
  # print node.box
  # print node.screenBox

  ## Draws the node.
  ##
  ## This is the primary routine that handles setting up the OpenGL
  ## context that will get rendered. This doesn't trigger the actual
  ## OpenGL rendering, but configures the various shaders and elements.
  ##
  ## Note that visiable draw calls need to check they're on the current
  ## active ZLevel (z-index).
  if disableRender in node.attrs:
    return
  
  # setup the opengl context to match the current node size and position

  ctx.saveTransform()
  ctx.translate(node.screenBox.xy)

  # handles setting up scrollbar region
  ifrender node.kind == nkScrollBar:
    ctx.saveTransform()
    let offset = parent.offset
    ctx.translate(offset)
  finally:
    ctx.restoreTransform()

  # handle node rotation
  ifrender node.rotation != 0:
    ctx.translate(node.screenBox.wh/2)
    ctx.rotate(node.rotation/180*PI)
    ctx.translate(-node.screenBox.wh/2)

  # handle clipping children content based on this node
  ifrender clipContent in node.attrs:
    ctx.beginMask()
    ctx.drawMasks(node)
    ctx.endMask()
  finally:
    ctx.popMask()

  # hacky method to draw drop shadows... should probably be done in opengl sharders
  ifrender node.kind == nkRectangle and node.shadow.isSome():
    ctx.renderShadows(node)

  ifrender true:
    if node.kind == nkText:
      ctx.renderText(node)
    elif node.kind == nkDrawable:
      ctx.renderDrawable(node)
    elif node.kind == nkRectangle:
      ctx.renderBoxes(node)

  # restores the opengl context back to the parent node's (see above)
  ctx.restoreTransform()

  ifrender scrollPanel in node.attrs:
    # handles scrolling panel
    ctx.saveTransform()
    ctx.translate(-node.offset)
  finally:
    ctx.restoreTransform()

  # echo "draw:children: ", repr childIdxs 
  for childIdx in childIndex(nodes, nodeIdx):
    ctx.render(nodes, childIdx, nodeIdx)

  # finally blocks will be run here, in reverse order
  postRender()

proc renderRoot*(ctx: Context, nodes: var RenderNodes) {.forbids: [MainThreadEff].} =
  # draw root for each level
  # currLevel = zidx
  var img: (Hash, Image)
  while glyphImageChan.tryRecv(img):
    # echo "img: ", img
    ctx.putImage(img[0], img[1])

  for zlvl, list in nodes.pairs():
    for rootIdx in list.rootIds:
      ctx.render(list.nodes, rootIdx, -1.NodeIdx)

proc renderFrame*(renderer: Renderer) =
  let ctx: Context = renderer.ctx
  clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
  ctx.beginFrame(renderer.frame.windowRawSize)
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

proc renderAndSwap(renderer: Renderer,
                   updated: bool) =
  ## Does drawing operations.

  app.tickCount.inc

  timeIt(drawFrame):
    renderFrame(renderer)

  var error: GLenum
  while (error = glGetError(); error != GL_NO_ERROR):
    echo "gl error: " & $error.uint32

  timeIt(drawFrameSwap):
    renderer.window.swapBuffers()

proc render*(renderer: Renderer, updated = false, poll = true) =
  ## renders and draws a window given set of nodes passed
  ## in via the Renderer object
  # let update = renderer.updated or updated
  let update = renderer.chan.tryRecv(renderer.nodes)

  if renderer.window.closeRequested:
    renderer.frame.running = false
    return

  timeIt(eventPolling):
    if poll:
      windy.pollEvents()
  
  if update:
    renderAndSwap(renderer, update)

