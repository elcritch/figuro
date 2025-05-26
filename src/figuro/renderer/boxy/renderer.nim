import std/[hashes, os, tables, times, monotimes, unicode, atomics]
import std/locks
export tables

import pkg/boxy
import pkg/chronicles

import ../../common/rchannels
import ../../common/nodes/uinodes
import ../utils/glutils
import ../utils/baserenderer
import ./glcommons
import ./drawextras

const FastShadows {.booldefine: "figuro.fastShadows".}: bool = false

type BoxyRenderer* = ref object of Renderer
  bxy*: Boxy

var boxyKey = newStringOfCap(128) 

template toKey(hash: Hash): string =
  boxyKey.setLen(0)
  boxyKey.add($hash)
  boxyKey

proc newBoxyRenderer*(
    window: RendererWindow,
    frame: WeakRef[AppFrame],
    forcePixelScale: float32,
    atlasSize: int,
): BoxyRenderer =
  result = BoxyRenderer(window: window)
  configureBaseRenderer(result, frame, forcePixelScale, atlasSize)
  result.bxy = newBoxy(atlasSize = atlasSize)

proc renderDrawable*(bxy: Boxy, node: Node) =
  # ## TODO: draw non-node stuff?
  discard

proc renderText(bxy: Boxy, node: Node) {.forbids: [AppMainThreadEff].} =
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
    if not bxy.hasImage(toKey(glyphId)):
      trace "no glyph in context: ", glyphId= glyphId, glyph= glyph.rune, glyphRepr= repr(glyph.rune)
      continue
    bxy.drawImage(toKey(glyphId), charPos, node.fill)

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

proc drawMasks(bxy: Boxy, node: Node) =
  if node.cornerRadius != [0'f32, 0'f32, 0'f32, 0'f32]:
    bxy.drawRoundedRect(
      rect(0, 0, node.screenBox.w, node.screenBox.h),
      rgba(255, 0, 0, 255).color,
      node.cornerRadius,
    )
  else:
    bxy.drawRect(
      rect(0, 0, node.screenBox.w, node.screenBox.h), rgba(255, 0, 0, 255).color
    )

proc renderDropShadows(bxy: Boxy, node: Node) =
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
          bxy.fillRoundedRect(rect = box, color = color, radius = node.cornerRadius)
    else:
      discard
      # bxy.fillRoundedRectWithShadow(
      #   rect = node.screenBox.atXY(0'f32, 0'f32),
      #   radii = node.cornerRadius,
      #   shadowX = shadow.x,
      #   shadowY = shadow.y,
      #   shadowBlur = shadow.blur,
      #   shadowSpread = shadow.spread.float32,
      #   shadowColor = shadow.color,
      #   innerShadow = false,
      # )

proc renderInnerShadows(bxy: Boxy, node: Node) =
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
      bxy.strokeRoundedRect(
        rect = box,
        color = color,
        weight = blur,
        radius = node.cornerRadius - blur,
      )
  else:
    discard
    # let shadow = node.shadow[InnerShadow]
    # var rect = node.screenBox.atXY(0'f32, 0'f32)
    # bxy.fillRoundedRectWithShadow(
    #   rect = node.screenBox.atXY(0'f32, 0'f32),
    #   radii = node.cornerRadius,
    #   shadowX = shadow.x,
    #   shadowY = shadow.y,
    #   shadowBlur = shadow.blur,
    #   shadowSpread = shadow.spread.float32,
    #   shadowColor = shadow.color,
    #   innerShadow = true,
    # )

proc cacheImage*(bxy: Boxy, filePath: string, imageId: Hash): bool =
  if bxy.hasImage(toKey(imageId)):
    return true
  let image = readImage(filePath)
  if image.width == 0 or image.height == 0:
    return false
  bxy.addImage(toKey(imageId), image)
  return true

proc renderBoxes(bxy: Boxy, node: Node) =
  ## drawing boxes for rectangles
  if node.fill.a > 0'f32:
    if node.cornerRadius != [0'f32, 0'f32, 0'f32, 0'f32]:
      discard
      bxy.drawRoundedRect(
        rect = node.screenBox.atXY(0'f32, 0'f32),
        color = node.fill,
        radii = node.cornerRadius,
        weight = node.stroke.weight,
      )
    else:
      bxy.drawRect(node.screenBox.atXY(0'f32, 0'f32), node.fill)

  if node.highlight.a > 0'f32:
    if node.cornerRadius != [0'f32, 0'f32, 0'f32, 0'f32]:
      bxy.drawRoundedRect(
        rect = node.screenBox.atXY(0'f32, 0'f32),
        color = node.highlight,
        radii = node.cornerRadius,
        weight = node.stroke.weight,
      )
    else:
      bxy.drawRect(node.screenBox.atXY(0'f32, 0'f32), node.highlight)

  if node.image.id.int != 0:
    let size = vec2(node.screenBox.w, node.screenBox.h)
    if bxy.cacheImage(node.image.name, node.image.id.Hash):
      let rect = rect(0, 0, size.x, size.y)
      bxy.drawImage(toKey(node.image.id.Hash), rect, node.image.color)

  if node.stroke.color.a > 0 and node.stroke.weight > 0:
    bxy.drawRoundedRect(
      rect = node.screenBox.atXY(0'f32, 0'f32),
      color = node.stroke.color,
      radii = node.cornerRadius,
      weight = node.stroke.weight,
      doStroke = true,
    )

proc render(
    bxy: Boxy, nodes: seq[Node], nodeIdx, parentIdx: NodeIdx
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

  bxy.saveTransform()
  bxy.translate(node.screenBox.xy)

  # handle node rotation
  ifrender node.rotation != 0:
    bxy.translate(node.screenBox.wh / 2)
    bxy.rotate(node.rotation / 180 * PI)
    bxy.translate(-node.screenBox.wh / 2)

  ifrender node.kind == nkRectangle and node.shadow[DropShadow].blur > 0.0:
    bxy.renderDropShadows(node)

  # handle clipping children content based on this node
  ifrender NfClipContent in node.flags:
    bxy.pushLayer()
  finally:
    bxy.pushLayer()
    bxy.drawRoundedRect(
      node.screenBox,
      rgba(255, 0, 0, 255).color,
      node.cornerRadius,
    )
    bxy.popLayer(blendMode = MaskBlend)
    bxy.popLayer(blendMode = NormalBlend)

  ifrender true:
    if node.kind == nkText:
      bxy.renderText(node)
    elif node.kind == nkDrawable:
      bxy.renderDrawable(node)
    elif node.kind == nkRectangle:
      bxy.renderBoxes(node)

  ifrender node.kind == nkRectangle and node.shadow[InnerShadow].blur > 0.0:
    bxy.pushLayer()
    bxy.saveTransform()
    bxy.translate(-node.screenBox.xy)
    bxy.drawRoundedRect(
      rect(0, 0, node.screenBox.w, node.screenBox.h),
      node.shadow[InnerShadow].color,
      node.cornerRadius,
      weight = node.shadow[InnerShadow].spread,
      doStroke = true,
    )
    bxy.blurEffect(node.shadow[InnerShadow].blur)
    # bxy.dropShadowEffect(
    #   color(1, 0, 0, 1),
    #   vec2(node.shadow[InnerShadow].x, node.shadow[InnerShadow].y),
    #   node.shadow[InnerShadow].blur,
    #   node.shadow[InnerShadow].spread,
    # )
    bxy.restoreTransform()
    bxy.popLayer(blendMode = NormalBlend)

  # restores the opengl context back to the parent node's (see above)
  bxy.restoreTransform()

  for childIdx in childIndex(nodes, nodeIdx):
    bxy.render(nodes, childIdx, nodeIdx)

  # finally blocks will be run here, in reverse order
  postRender()

proc renderRoot*(bxy: Boxy, nodes: var Renders) {.forbids: [AppMainThreadEff].} =
  # draw root for each level
  # currLevel = zidx
  var img: (Hash, Image)
  while glyphImageChan.tryRecv(img):
    # echo "img: ", img
    bxy.addImage(toKey(img[0]), img[1])

  for zlvl, list in nodes.layers.pairs():
    for rootIdx in list.rootIds:
      bxy.render(list.nodes, rootIdx, -1.NodeIdx)

proc renderFrame*(renderer: BoxyRenderer) =
  let bxy: Boxy = renderer.bxy
  clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
  let
    size = renderer.window.info.box.wh.scaled()
    isize = ivec2(size)
  bxy.beginFrame(isize)
  bxy.pushLayer()
  bxy.saveTransform()

  # draw root
  bxy.renderRoot(renderer.nodes)

  bxy.restoreTransform()
  bxy.popLayer()
  bxy.endFrame()

  when defined(testOneFrame):
    ## This is used for test only
    ## Take a screen shot of the first frame and exit.
    var img = takeScreenshot()
    img.writeFile("screenshot.png")
    quit()

method renderAndSwap*(renderer: BoxyRenderer) =
  ## Does drawing operations.

  timeIt(drawFrame):
    renderFrame(renderer)

  for error in glErrors():
    echo error

  timeIt(drawFrameSwap):
    renderer.window.swapBuffers()
