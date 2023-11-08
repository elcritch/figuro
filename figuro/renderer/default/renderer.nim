import std/[hashes, os, strformat, tables, times, unicode]

import pixie, windy, opengl, boxy, chroma

import ../../shared
import ../../common/nodes/render
import ../../common/nodes/transfer
import ../../timers
import ../../common/glyphs
import ../fontutils

import context
export tables
export getTypeface, getTypeset

type
  Renderer* = ref object
    window*: Window
    ctx*: RContext
    nodes*: RenderNodes
    updated*: bool

proc renderDrawable*(ctx: RContext, node: Node) =
  # ctx: RContext, poly: seq[Vec2], weight: float32, color: Color
  for point in node.points:
    # ctx.linePolygon(node.poly, node.stroke.weight, node.stroke.color)
    let
      pos = point
      bx = node.box.atXY(pos.x, pos.y)
    ctx.fillRect(bx, node.fill)

proc renderText(ctx: RContext, node: Node) {.forbids: [MainThreadEff].} =
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
      let hkey = $glyphId
      ctx.entries[glyphId] = hkey
      echo "no glyph in context: ", glyphId, " glyph: `", glyph.rune, "`", " (", repr(glyph.rune), ")"
      continue
    ctx.drawImage(glyphId, charPos, node.fill)

import macros

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

proc drawMasks*(ctx: RContext, node: Node) =
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

proc renderShadows*(ctx: RContext, node: Node) =
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

proc renderBoxes*(ctx: RContext, node: Node) =
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
    assert false, "TODO"
  #   let path = dataDir / node.image.name
  #   let size = vec2(node.screenBox.w, node.screenBox.h)
  #   ctx.drawImage(path,
  #                 pos = vec2(0, 0),
  #                 color = node.image.color,
  #                 size = size)
  
  if node.stroke.color.a > 0 and node.stroke.weight > 0:
    ctx.strokeRoundedRect(rect = node.screenBox.atXY(0'f32, 0'f32),
                          color = node.stroke.color,
                          weight = node.stroke.weight,
                          radius = node.cornerRadius)


proc render*(ctx: RContext, nodes: seq[Node], nodeIdx, parentIdx: NodeIdx) {.forbids: [MainThreadEff].} =

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

  ctx.boxy.saveTransform()
  ctx.boxy.translate(node.screenBox.xy)

  # handles setting up scrollbar region
  ifrender node.kind == nkScrollBar:
    ctx.boxy.saveTransform()
    let offset = parent.offset
    ctx.boxy.translate(offset)
  finally:
    ctx.boxy.restoreTransform()

  # handle node rotation
  ifrender node.rotation != 0:
    ctx.boxy.translate(node.screenBox.wh/2)
    ctx.boxy.rotate(node.rotation/180*PI)
    ctx.boxy.translate(-node.screenBox.wh/2)

  # # handle clipping children content based on this node
  # ifrender clipContent in node.attrs:
  #   ctx.boxy.saveTransform()
  #   ctx.boxy.pushLayer()
  #   # ctx.drawMasks(node)
  #   # ctx.boxy.pushLayer()
  #   ctx.boxy.popLayer()
  #   ctx.boxy.restoreTransform()
  # finally:
  #   # ctx.boxy.popLayer()
  #   # ctx.boxy.popLayer()
  #   discard

  # hacky method to draw drop shadows... should probably be done in opengl sharders
  ifrender node.kind == nkRectangle and node.shadow.isSome():
    # boxy.renderShadows()
    assert false, "TODO"

  ifrender true:
    if node.kind == nkText:
      ctx.renderText(node)
    elif node.kind == nkDrawable:
      ctx.renderDrawable(node)
    elif node.kind == nkRectangle:
      ctx.renderBoxes(node)

  # restores the opengl context back to the parent node's (see above)
  ctx.boxy.restoreTransform()

  ifrender scrollPanel in node.attrs:
    # handles scrolling panel
    ctx.boxy.saveTransform()
    ctx.boxy.translate(-node.offset)
  finally:
    ctx.boxy.restoreTransform()

  # echo "draw:children: ", repr childIdxs 
  for childIdx in childIndex(nodes, nodeIdx):
    ctx.render(nodes, childIdx, nodeIdx)

  # finally blocks will be run here, in reverse order
  postRender()

proc renderRoot*(ctx: RContext, nodes: var RenderNodes) {.forbids: [MainThreadEff].} =
  # draw root for each level
  # currLevel = zidx
  var img: (Hash, Image)
  while glyphImageChan.tryRecv(img):
    # echo "img: ", img
    ctx.putImage(img[0], img[1])

  for zlvl, list in nodes.pairs():
    for rootIdx in list.rootIds:
      ctx.render(list.nodes, rootIdx, -1.NodeIdx)

proc renderFrame*(ctx: RContext, nodes: var RenderNodes) =
  # clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
  let size = ivec2(app.windowRawSize.x.toInt.int32, app.windowRawSize.y.toInt.int32)
  ctx.boxy.beginFrame(size)
  ctx.boxy.saveTransform()
  ctx.boxy.scale(vec2(app.pixelScale, app.pixelScale))

  ctx.renderRoot(nodes)

  ctx.boxy.restoreTransform()
  ctx.boxy.endFrame()

  when defined(testOneFrame):
    ## This is used for test only
    ## Take a screen shot of the first frame and exit.
    var img = takeScreenshot()
    img.writeFile("screenshot.png")
    quit()

proc renderLoop*(ctx: RContext,
                window: Window,
                nodes: var RenderNodes,
                updated: bool,
                poll = true) =
  if window.closeRequested:
    app.running = false
    return

  timeIt(eventPolling):
    if poll:
      windy.pollEvents()
  
  if updated:
    app.tickCount.inc

    timeIt(drawFrame):
      ctx.renderFrame(nodes)

    timeIt(drawFrameSwap):
      window.swapBuffers()

proc render*(renderer: Renderer, updated = false, poll = true) =
  let update = renderer.updated or updated
  renderer.updated = false
  renderLoop(renderer.ctx,
             renderer.window,
             renderer.nodes,
             update, poll)
