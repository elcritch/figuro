import std/hashes, unicode, os, strformat, tables, times

# import typography
import pixie, chroma

import context, formatflippy
import commons

type
  Context = context.Context

var
  ctx*: Context
  glyphOffsets: Table[Hash, Vec2]

  # Used for double-clicking
  # currLevel: ZLevel

proc hashFontFill(node: Node, pos: GlyphPosition, subPixelShift: float32): Hash {.inline.} =
  result = hash((
    2344,
    node.textStyle.fontFamily,
    pos.rune,
    (node.textStyle.fontSize*100).int,
    (subPixelShift*100).int,
    0
  ))

proc hashFontStroke(node: Node, pos: GlyphPosition, subPixelShift: float32): Hash {.inline.} =
  result = hash((
    9812,
    node.textStyle.fontFamily,
    pos.rune,
    (node.textStyle.fontSize*100).int,
    (subPixelShift*100).int,
    node.stroke.weight
  ))

proc renderBoxes*(node: Node)

proc drawDrawable*(node: Node) =
  # ctx: Context, poly: seq[Vec2], weight: float32, color: Color
  for point in node.points:
    # ctx.linePolygon(node.poly, node.stroke.weight, node.stroke.color)
    let
      pos = point
      bx = node.box.atXY(pos.x, pos.y)
    ctx.fillRect(bx, node.fill)

# proc drawText(node: Node) =
#   if node.textStyle.fontFamily notin fonts:
#     quit &"font not found: {node.textStyle.fontFamily}"

#   var font = fonts[node.textStyle.fontFamily]
#   font.size = node.textStyle.fontSize.scaled
#   font.lineHeight = node.textStyle.lineHeight.scaled
#   # if font.lineHeight == 0:
#   #   font.lineHeight = defaultLineHeight(node.textStyle).scaled

#   # draw characters
#   for glyphIdx, pos in node.textLayout:
#     if $pos.rune notin font.typeface.glyphs:
#       continue
#     if pos.rune == Rune(32):
#       # Don't draw space, even if font has a char for it.
#       # FIXME: use unicode 'is whitespace' ?
#       continue

#     let
#       font = node.textStyle.font
#       subPixelShift = floor(pos.subPixelShift * 10) / 10
#       hashFill = node.hashFontFill(pos, subPixelShift)

#     var
#       hashStroke: Hash

#     if hashFill notin ctx.entries:
#       var
#         glyph = font.typeface.glyphs[pos.character]
#         glyphOffset: Vec2
#       let
#         glyphFill = font.getGlyphImage(glyph, glyphOffset, subPixelShift=subPixelShift)

#       ctx.putImage(hashFill, glyphFill)
#       glyphOffsets[hashFill] = glyphOffset

#     if node.stroke.weight > 0:
#       hashStroke = node.hashFontStroke(pos, subPixelShift)

#       if hashStroke notin ctx.entries:
#         var
#           glyph = font.typeface.glyphs[pos.character]
#           glyphOffset: Vec2
#         let
#           glyphFill = font.getGlyphImage( glyph, glyphOffset, subPixelShift=subPixelShift)

#         let glyphStroke = glyphFill.outlineBorder(node.stroke.weight.int)
#         ctx.putImage(hashStroke, glyphStroke)

#     let
#       glyphOffset = glyphOffsets[hashFill]
#       charPos = vec2(pos.rect.x + glyphOffset.x, pos.rect.y + glyphOffset.y)

#     if node.stroke.weight > 0 and node.stroke.color.a > 0:
#       ctx.drawImage(
#         hashStroke,
#         charPos - vec2(node.stroke.weight,
#                        node.stroke.weight),
#         node.stroke.color
#       )

#     ctx.drawImage(hashFill, charPos, node.fill)
  
import macros

var postDrawsImpl {.compileTime.}: seq[NimNode]

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
    postDrawsImpl.add quote do:
      if `checkval`:
        `postBlock`

macro postDraws() =
  result = newStmtList()
  while postDrawsImpl.len() > 0:
    result.add postDrawsImpl.pop()

proc drawMasks*(node: Node) =
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

proc renderShadows*(node: Node) =
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

proc renderBoxes*(node: Node) =
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

proc render*(nodes: var seq[Node], nodeIdx, parentIdx: NodeIdx) =

  template node(): auto = nodes[nodeIdx]
  template parent(): auto = nodes[parentIdx]

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
    node.drawMasks()
    ctx.endMask()
  finally:
    ctx.popMask()

  # hacky method to draw drop shadows... should probably be done in opengl sharders
  ifrender node.kind == nkRectangle and node.shadow.isSome():
    node.renderShadows()

  ifrender true:
    if node.kind == nkText:
      # node.drawText()
      discard
    elif node.kind == nkDrawable:
      node.drawDrawable()
    elif node.kind == nkRectangle:
      node.renderBoxes()

  # restores the opengl context back to the parent node's (see above)
  ctx.restoreTransform()

  ifrender scrollpane in node.attrs:
    # handles scrolling panel
    ctx.saveTransform()
    ctx.translate(-node.offset)
  finally:
    ctx.restoreTransform()

  let childIdxs = childIndex(nodes, nodeIdx)
  # echo "draw:children: ", repr childIdxs 
  for childIdx in childIdxs:
    render(nodes, childIdx, nodeIdx)

  # finally blocks will be run here, in reverse order
  postDraws()

proc renderRoot*(nodes: var seq[Node]) =
  # draw root for each level
  # currLevel = zidx
  # echo "drawRoot:nodes:count: ", nodes.len()
  if nodes.len() > 0:
    render(nodes, 0.NodeIdx, -1.NodeIdx)

