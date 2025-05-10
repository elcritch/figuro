import
  buffers, chroma, pixie, hashes, opengl, os, shaders, strformat, strutils, tables,
  textures, times, formatflippy

import pixie/simd

import pkg/chronicles

import ../../commons

logScope:
  scope = "opengl"

const quadLimit = 10_921

type Context* = ref object
  atlasShader, maskShader, activeShader: Shader
  atlasTexture: Texture
  maskTextureWrite: int ## Index into max textures for writing.
  maskTextureRead: int ## Index into max textures for rendering.
  maskTextures: seq[Texture] ## Masks array for pushing and popping.
  atlasSize: int ## Size x size dimensions of the atlas
  atlasMargin: int ## Default margin between images
  quadCount: int ## Number of quads drawn so far
  maxQuads: int ## Max quads to draw before issuing an OpenGL call
  mat*: Mat4 ## Current matrix
  mats: seq[Mat4] ## Matrix stack
  entries*: Table[Hash, Rect] ## Mapping of image name to atlas UV position
  heights: seq[uint16] ## Height map of the free space in the atlas
  proj*: Mat4
  frameSize: Vec2 ## Dimensions of the window frame
  vertexArrayId, maskFramebufferId: GLuint
  frameBegun, maskBegun: bool
  pixelate*: bool ## Makes texture look pixelated, like a pixel game.
  pixelScale*: float32 ## Multiple scaling factor.

  # Buffer data for OpenGL
  positions: tuple[buffer: Buffer, data: seq[float32]]
  colors: tuple[buffer: Buffer, data: seq[uint8]]
  uvs: tuple[buffer: Buffer, data: seq[float32]]
  indices: tuple[buffer: Buffer, data: seq[uint16]]

proc draw(ctx: Context)

proc upload(ctx: Context) =
  ## When buffers change, uploads them to GPU.
  ctx.positions.buffer.count = ctx.quadCount * 4
  ctx.colors.buffer.count = ctx.quadCount * 4
  ctx.uvs.buffer.count = ctx.quadCount * 4
  ctx.indices.buffer.count = ctx.quadCount * 6
  bindBufferData(ctx.positions.buffer.addr, ctx.positions.data[0].addr)
  bindBufferData(ctx.colors.buffer.addr, ctx.colors.data[0].addr)
  bindBufferData(ctx.uvs.buffer.addr, ctx.uvs.data[0].addr)

proc setUpMaskFramebuffer(ctx: Context) =
  glBindFramebuffer(GL_FRAMEBUFFER, ctx.maskFramebufferId)
  glFramebufferTexture2D(
    GL_FRAMEBUFFER,
    GL_COLOR_ATTACHMENT0,
    GL_TEXTURE_2D,
    ctx.maskTextures[ctx.maskTextureWrite].textureId,
    0,
  )

proc createAtlasTexture(ctx: Context, size: int): Texture =
  result.width = size.GLint
  result.height = size.GLint
  result.componentType = GL_UNSIGNED_BYTE
  result.format = GL_RGBA
  result.internalFormat = GL_RGBA8
  result.genMipmap = true
  result.minFilter = minLinearMipmapLinear
  if ctx.pixelate:
    result.magFilter = magNearest
  else:
    result.magFilter = magLinear
  bindTextureData(result.addr, nil)

proc addMaskTexture(ctx: Context, frameSize = vec2(1, 1)) =
  # Must be >0 for framebuffer creation below
  # Set to real value in beginFrame
  var maskTexture = Texture()
  maskTexture.width = frameSize.x.int32
  maskTexture.height = frameSize.y.int32
  maskTexture.componentType = GL_UNSIGNED_BYTE
  maskTexture.format = GL_RGBA
  when defined(emscripten):
    maskTexture.internalFormat = GL_RGBA8
  else:
    maskTexture.internalFormat = GL_R8
  maskTexture.minFilter = minLinear
  if ctx.pixelate:
    maskTexture.magFilter = magNearest
  else:
    maskTexture.magFilter = magLinear
  bindTextureData(maskTexture.addr, nil)
  ctx.maskTextures.add(maskTexture)

proc newContext*(
    atlasSize = 1024,
    atlasMargin = 4,
    maxQuads = 1024,
    pixelate = false,
    pixelScale = 1.0,
): Context =
  ## Creates a new context.
  if maxQuads > quadLimit:
    raise newException(ValueError, &"Quads cannot exceed {quadLimit}")

  result = Context()
  result.atlasSize = atlasSize
  result.atlasMargin = atlasMargin
  result.maxQuads = maxQuads
  result.mat = mat4()
  result.mats = newSeq[Mat4]()
  result.pixelate = pixelate
  result.pixelScale = pixelScale

  result.heights = newSeq[uint16](atlasSize)
  result.atlasTexture = result.createAtlasTexture(atlasSize)

  result.addMaskTexture()

  when defined(emscripten) or defined(useOpenGlEs):
    result.atlasShader =
      newShaderStatic("glsl/emscripten/atlas.vert", "glsl/emscripten/atlas.frag")
    result.maskShader =
      newShaderStatic("glsl/emscripten/atlas.vert", "glsl/emscripten/mask.frag")
  else:
    try:
      result.atlasShader = newShaderStatic("glsl/atlas.vert", "glsl/atlas.frag")
      result.maskShader = newShaderStatic("glsl/atlas.vert", "glsl/mask.frag")
    except ShaderCompilationError:
      info "OpenGL 3.30 failed, trying GLSL ES"
      result.atlasShader =
        newShaderStatic("glsl/emscripten/atlas.vert", "glsl/emscripten/atlas.frag")
      result.maskShader =
        newShaderStatic("glsl/emscripten/atlas.vert", "glsl/emscripten/mask.frag")

  result.positions.buffer.componentType = cGL_FLOAT
  result.positions.buffer.kind = bkVEC2
  result.positions.buffer.target = GL_ARRAY_BUFFER
  result.positions.data =
    newSeq[float32](result.positions.buffer.kind.componentCount() * maxQuads * 4)

  result.colors.buffer.componentType = GL_UNSIGNED_BYTE
  result.colors.buffer.kind = bkVEC4
  result.colors.buffer.target = GL_ARRAY_BUFFER
  result.colors.buffer.normalized = true
  result.colors.data =
    newSeq[uint8](result.colors.buffer.kind.componentCount() * maxQuads * 4)

  result.uvs.buffer.componentType = cGL_FLOAT
  result.uvs.buffer.kind = bkVEC2
  result.uvs.buffer.target = GL_ARRAY_BUFFER
  result.uvs.data =
    newSeq[float32](result.uvs.buffer.kind.componentCount() * maxQuads * 4)

  result.indices.buffer.componentType = GL_UNSIGNED_SHORT
  result.indices.buffer.kind = bkSCALAR
  result.indices.buffer.target = GL_ELEMENT_ARRAY_BUFFER
  result.indices.buffer.count = maxQuads * 6

  for i in 0 ..< maxQuads:
    let offset = i * 4
    result.indices.data.add(
      [
        (offset + 3).uint16,
        (offset + 0).uint16,
        (offset + 1).uint16,
        (offset + 2).uint16,
        (offset + 3).uint16,
        (offset + 1).uint16,
      ]
    )

  # Indices are only uploaded once
  bindBufferData(result.indices.buffer.addr, result.indices.data[0].addr)

  result.upload()

  result.activeShader = result.atlasShader

  glGenVertexArrays(1, result.vertexArrayId.addr)
  glBindVertexArray(result.vertexArrayId)

  result.activeShader.bindAttrib("vertexPos", result.positions.buffer)
  result.activeShader.bindAttrib("vertexColor", result.colors.buffer)
  result.activeShader.bindAttrib("vertexUv", result.uvs.buffer)

  # Create mask framebuffer
  glGenFramebuffers(1, result.maskFramebufferId.addr)
  result.setUpMaskFramebuffer()

  let status = glCheckFramebufferStatus(GL_FRAMEBUFFER)
  if status != GL_FRAMEBUFFER_COMPLETE:
    quit(&"Something wrong with mask framebuffer: {toHex(status.int32, 4)}")

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

func `[]=`(t: var Table[Hash, Rect], key: string, rect: Rect) =
  t[hash(key)] = rect

func `[]`(t: var Table[Hash, Rect], key: string): Rect =
  t[hash(key)]

proc hash(v: Vec2): Hash =
  hash((v.x, v.y))

proc hash(radii: array[DirectionCorners, float32]): Hash =
  for r in radii:
    result = result !& hash(r)

proc grow(ctx: Context) =
  ctx.draw()
  ctx.atlasSize = ctx.atlasSize * 2
  info "grow atlasSize ", atlasSize = ctx.atlasSize
  ctx.heights.setLen(ctx.atlasSize)
  ctx.atlasTexture = ctx.createAtlasTexture(ctx.atlasSize)
  ctx.entries.clear()

proc findEmptyRect(ctx: Context, width, height: int): Rect =
  var imgWidth = width + ctx.atlasMargin * 2
  var imgHeight = height + ctx.atlasMargin * 2

  var lowest = ctx.atlasSize
  var at = 0
  for i in 0 .. ctx.atlasSize - 1:
    var v = int(ctx.heights[i])
    if v < lowest:
      # found low point, is it consecutive?
      var fit = true
      for j in 0 .. imgWidth:
        if i + j >= ctx.atlasSize:
          fit = false
          break
        if int(ctx.heights[i + j]) > v:
          fit = false
          break
      if fit:
        # found!
        lowest = v
        at = i

  if lowest + imgHeight > ctx.atlasSize:
    #raise newException(Exception, "Context Atlas is full")
    ctx.grow()
    return ctx.findEmptyRect(width, height)

  for j in at .. at + imgWidth - 1:
    ctx.heights[j] = uint16(lowest + imgHeight + ctx.atlasMargin * 2)

  var rect = rect(
    float32(at + ctx.atlasMargin),
    float32(lowest + ctx.atlasMargin),
    float32(width),
    float32(height),
  )

  return rect

proc putImage*(ctx: Context, path: Hash, image: Image) =
  # Reminder: This does not set mipmaps (used for text, should it?)
  let rect = ctx.findEmptyRect(image.width, image.height)
  ctx.entries[path] = rect / float(ctx.atlasSize)
  updateSubImage(ctx.atlasTexture, int(rect.x), int(rect.y), image)

proc updateImage*(ctx: Context, path: Hash, image: Image) =
  ## Updates an image that was put there with putImage.
  ## Useful for things like video.
  ## * Must be the same size.
  ## * This does not set mipmaps.
  let rect = ctx.entries[path]
  assert rect.w == image.width.float / float(ctx.atlasSize)
  assert rect.h == image.height.float / float(ctx.atlasSize)
  updateSubImage(
    ctx.atlasTexture,
    int(rect.x * ctx.atlasSize.float),
    int(rect.y * ctx.atlasSize.float),
    image,
  )

proc logFlippy(flippy: Flippy, file: string) =
  debug "putFlippy file", fwidth = $flippy.width, fheight = $flippy.height, flippyPath = file

proc putFlippy*(ctx: Context, path: Hash, flippy: Flippy) =
  logFlippy(flippy, $path)
  let rect = ctx.findEmptyRect(flippy.width, flippy.height)
  ctx.entries[path] = rect / float(ctx.atlasSize)
  var
    x = int(rect.x)
    y = int(rect.y)
  for level, mip in flippy.mipmaps:
    updateSubImage(ctx.atlasTexture, x, y, mip, level)
    x = x div 2
    y = y div 2

proc draw(ctx: Context) =
  ## Flips - draws current buffer and starts a new one.
  if ctx.quadCount == 0:
    return

  ctx.upload()

  glUseProgram(ctx.activeShader.programId)
  glBindVertexArray(ctx.vertexArrayId)

  if ctx.activeShader.hasUniform("windowFrame"):
    ctx.activeShader.setUniform("windowFrame", ctx.frameSize.x, ctx.frameSize.y)
  ctx.activeShader.setUniform("proj", ctx.proj)

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, ctx.atlasTexture.textureId)
  ctx.activeShader.setUniform("atlasTex", 0)

  if ctx.activeShader.hasUniform("maskTex"):
    glActiveTexture(GL_TEXTURE1)
    glBindTexture(GL_TEXTURE_2D, ctx.maskTextures[ctx.maskTextureRead].textureId)
    ctx.activeShader.setUniform("maskTex", 1)

  ctx.activeShader.bindUniforms()

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ctx.indices.buffer.bufferId)
  glDrawElements(
    GL_TRIANGLES, ctx.indices.buffer.count.GLint, ctx.indices.buffer.componentType, nil
  )

  ctx.quadCount = 0

proc checkBatch(ctx: Context) =
  if ctx.quadCount == ctx.maxQuads:
    # ctx is full dump the images in the ctx now and start a new batch
    ctx.draw()

proc setVert2(buf: var seq[float32], i: int, v: Vec2) =
  buf[i * 2 + 0] = v.x
  buf[i * 2 + 1] = v.y

proc setVertColor(buf: var seq[uint8], i: int, color: ColorRGBA) =
  buf[i * 4 + 0] = color.r
  buf[i * 4 + 1] = color.g
  buf[i * 4 + 2] = color.b
  buf[i * 4 + 3] = color.a

func `*`*(m: Mat4, v: Vec2): Vec2 =
  (m * vec3(v.x, v.y, 0.0)).xy

proc drawQuad*(
    ctx: Context,
    verts: array[4, Vec2],
    uvs: array[4, Vec2],
    colors: array[4, ColorRGBA],
) =
  ctx.checkBatch()

  let offset = ctx.quadCount * 4
  ctx.positions.data.setVert2(offset + 0, verts[0])
  ctx.positions.data.setVert2(offset + 1, verts[1])
  ctx.positions.data.setVert2(offset + 2, verts[2])
  ctx.positions.data.setVert2(offset + 3, verts[3])

  ctx.uvs.data.setVert2(offset + 0, uvs[0])
  ctx.uvs.data.setVert2(offset + 1, uvs[1])
  ctx.uvs.data.setVert2(offset + 2, uvs[2])
  ctx.uvs.data.setVert2(offset + 3, uvs[3])

  ctx.colors.data.setVertColor(offset + 0, colors[0])
  ctx.colors.data.setVertColor(offset + 1, colors[1])
  ctx.colors.data.setVertColor(offset + 2, colors[2])
  ctx.colors.data.setVertColor(offset + 3, colors[3])

  inc ctx.quadCount

proc drawUvRect(ctx: Context, at, to: Vec2, uvAt, uvTo: Vec2, color: Color) =
  ## Adds an image rect with a path to an ctx
  ctx.checkBatch()

  assert ctx.quadCount < ctx.maxQuads

  let
    posQuad = [
      ceil(ctx.mat * vec2(at.x, to.y)),
      ceil(ctx.mat * vec2(to.x, to.y)),
      ceil(ctx.mat * vec2(to.x, at.y)),
      ceil(ctx.mat * vec2(at.x, at.y)),
    ]
    uvQuad = [
      vec2(uvAt.x, uvTo.y),
      vec2(uvTo.x, uvTo.y),
      vec2(uvTo.x, uvAt.y),
      vec2(uvAt.x, uvAt.y),
    ]

  let offset = ctx.quadCount * 4
  ctx.positions.data.setVert2(offset + 0, posQuad[0])
  ctx.positions.data.setVert2(offset + 1, posQuad[1])
  ctx.positions.data.setVert2(offset + 2, posQuad[2])
  ctx.positions.data.setVert2(offset + 3, posQuad[3])

  ctx.uvs.data.setVert2(offset + 0, uvQuad[0])
  ctx.uvs.data.setVert2(offset + 1, uvQuad[1])
  ctx.uvs.data.setVert2(offset + 2, uvQuad[2])
  ctx.uvs.data.setVert2(offset + 3, uvQuad[3])

  let rgba = color.rgba()
  ctx.colors.data.setVertColor(offset + 0, rgba)
  ctx.colors.data.setVertColor(offset + 1, rgba)
  ctx.colors.data.setVertColor(offset + 2, rgba)
  ctx.colors.data.setVertColor(offset + 3, rgba)

  inc ctx.quadCount

proc drawUvRect(ctx: Context, rect, uvRect: Rect, color: Color) =
  ctx.drawUvRect(rect.xy, rect.xy + rect.wh, uvRect.xy, uvRect.xy + uvRect.wh, color)

proc logImage(file: string) =
  debug "load image file", flippyPath = file

proc getImageRect(ctx: Context, imageId: Hash): Rect =
  return ctx.entries[imageId]

proc loadImage*(ctx: Context, filePath: string): Flippy =

  # Need to load imagePath, check to see if the .flippy file is around
  logImage(filePath)
  if not fileExists(filePath):
    return Flippy()
  let flippyFilePath = filePath.changeFileExt(".flippy")
  if not fileExists(flippyFilePath):
    # No Flippy file generate new one
    pngToFlippy(filePath, flippyFilePath)
  else:
    let
      mtFlippy = getLastModificationTime(flippyFilePath).toUnix
      mtImage = getLastModificationTime(filePath).toUnix
    if mtFlippy < mtImage:
      # Flippy file too old, regenerate
      pngToFlippy(filePath, flippyFilePath)
  result = loadFlippy(flippyFilePath)

proc cacheImage*(ctx: Context, filePath: string, imageId: Hash): bool =
  if imageId in ctx.entries:
    return true
  let image = ctx.loadImage(filePath)
  if image.width == 0 or image.height == 0:
    return false
  ctx.putFlippy(imageId, image)
  return true

proc drawImage*(
    ctx: Context,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    scale = 1.0,
) =
  ## Draws image the UI way - pos at top-left.
  let
    rect = ctx.getImageRect(imageId)
    wh = rect.wh * ctx.atlasSize.float32 * scale
  ctx.drawUvRect(pos, pos + wh, rect.xy, rect.xy + rect.wh, color)

proc drawImage*(
    ctx: Context,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    size: Vec2,
) =
  ## Draws image the UI way - pos at top-left.
  let rect = ctx.getImageRect(imageId)
  ctx.drawUvRect(pos, pos + size, rect.xy, rect.xy + rect.wh, color)

proc drawImageAdj*(
    ctx: Context,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    size: Vec2,
) =
  ## Draws image the UI way - pos at top-left.
  let
    rect = ctx.getImageRect(imageId)
    adj = vec2(2/ctx.atlasSize.float32)
  ctx.drawUvRect(pos, pos + size, rect.xy+adj, rect.xy + rect.wh - adj, color)

proc drawSprite*(
    ctx: Context,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    scale = 1.0,
) =
  ## Draws image the game way - pos at center.
  let
    rect = ctx.getImageRect(imageId)
    wh = rect.wh * ctx.atlasSize.float32 * scale
  ctx.drawUvRect(pos - wh / 2, pos + wh / 2, rect.xy, rect.xy + rect.wh, color)

proc drawSprite*(
    ctx: Context,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    size: Vec2,
) =
  ## Draws image the game way - pos at center.
  let rect = ctx.getImageRect(imageId)
  ctx.drawUvRect(pos - size / 2, pos + size / 2, rect.xy, rect.xy + rect.wh, color)

proc fillRect*(ctx: Context, rect: Rect, color: Color) =
  const imgKey = hash("rect")
  if imgKey notin ctx.entries:
    var image = newImage(4, 4)
    image.fill(rgba(255, 255, 255, 255))
    ctx.putImage(imgKey, image)

  let
    uvRect = ctx.entries[imgKey]
    wh = rect.wh * float32(ctx.atlasSize)
  ctx.drawUvRect(
    rect.xy,
    rect.xy + rect.wh,
    uvRect.xy + uvRect.wh / 2,
    uvRect.xy + uvRect.wh / 2,
    color,
  )

proc sliceToNinePatch(img: Image): tuple[
  topLeft, topRight, bottomLeft, bottomRight: Image,
  top, right, bottom, left: Image
] =
  ## Slices an image into 8 pieces for a 9-patch style UI renderer.
  ## The ninth piece (center) is not included as it's typically transparent or filled separately.
  ## Returns the four corners and four edges as separate images.
  
  let 
    width = img.width
    height = img.height
    halfW = width div 2
    halfH = height div 2
  
  echo "sliceToNinePatch: ", width, "x", height, " halfW: ", halfW, " halfH: ", halfH

  # Create the corner images - using the actual corner size or half the image size, whichever is smaller
  let 
    actualCornerW = halfW
    actualCornerH = halfH
  
  # Four corners
  let
    topLeft = img.subImage(0, 0, halfW, halfH)
    topRight = img.subImage(width - halfW, 0, halfW, halfH)
    bottomLeft = img.subImage(0, height - halfH, halfW, halfH)
    bottomRight = img.subImage(width - halfW, height - halfH, halfW, halfH)
  
  # Four edges (1 pixel wide for sides, full width/height for top/bottom)
  # Each edge goes from the center point to the edge
  let
    centerX = width div 2
    centerY = height div 2
    
    top = img.subImage(centerX, 0, 1, centerY)
    right = img.subImage(centerX, centerY, width - centerX, 1)
    bottom = img.subImage(centerX, centerY, 1, height - centerY)
    left = img.subImage(0, centerY, centerX, 1)
  
  var
    n = 8
    ftop = newImage(n, top.height)
    fbottom = newImage(n, bottom.height)
    fright = newImage(right.width, n)
    fleft = newImage(left.width, n)

  for i in 0..<n:
    ftop.draw(top, translate(vec2(i.float32, 0)))
    fbottom.draw(bottom, translate(vec2(i.float32, 0)))
    fright.draw(right, translate(vec2(0, i.float32)))
    fleft.draw(left, translate(vec2(0, i.float32)))

  result = (
    topLeft: topLeft,
    topRight: topRight,
    bottomLeft: bottomLeft,
    bottomRight: bottomRight,
    top: ftop,
    right: fright,
    bottom: fbottom,
    left: fleft
  )
  
proc generateCircleBox*(
    radii: array[DirectionCorners, float32],
    offset = vec2(0, 0),
    spread: float32 = 0.0'f32,
    blur: float32 = 0.0'f32,
    stroked: bool = true,
    lineWidth: float32 = 0.0'f32,
    fillStyle: ColorRGBA = rgba(255, 255, 255, 255),
    shadowColor: ColorRGBA = rgba(255, 255, 255, 255),
    outerShadow = true,
    innerShadow = true,
    innerShadowBorder = true,
    outerShadowFill = false,
): Image =
  var maxRadius = 0.0
  for r in radii:
    maxRadius = max(maxRadius, r)
  
  # Additional size for spread and blur
  let padding = (spread.int + blur.int)
  let totalSize = max(maxRadius.ceil().int * 2 + padding * 2, 10+padding*2)
  
  # Create a canvas large enough to contain the box with all effects
  let img = newImage(totalSize, totalSize)
  let ctx = newContext(img)
  
  # Calculate the inner box dimensions
  let innerWidth = (totalSize - padding * 2).float32
  let innerHeight = (totalSize - padding * 2).float32
  
  # Create a path for the rounded rectangle with the given dimensions and corner radii
  proc createRoundedRectPath(
    width, height: float32,
    radii: array[DirectionCorners, float32],
    padding: int
  ): pixie.Path =
    # Start at top right after the corner radius
    result = newPath()
    let topRight = vec2(width - radii[dcTopRight].float32, 0)
    result.moveTo(topRight + vec2(padding.float32, padding.float32))
    
    # Top right corner
    let trControl = vec2(width, 0)
    result.quadraticCurveTo(
      trControl + vec2(padding.float32, padding.float32),
      vec2(width, radii[dcTopRight].float32) + vec2(padding.float32, padding.float32)
    )
    
    # Right side
    result.lineTo(vec2(width, height - radii[dcBottomRight].float32) + vec2(padding.float32, padding.float32))
    
    # Bottom right corner
    let brControl = vec2(width, height)
    result.quadraticCurveTo(
      brControl + vec2(padding.float32, padding.float32),
      vec2(width - radii[dcBottomRight].float32, height) + vec2(padding.float32, padding.float32)
    )
    
    # Bottom side
    result.lineTo(vec2(radii[dcBottomLeft].float32, height) + vec2(padding.float32, padding.float32))
    
    # Bottom left corner
    let blControl = vec2(0, height)
    result.quadraticCurveTo(
      blControl + vec2(padding.float32, padding.float32),
      vec2(0, height - radii[dcBottomLeft].float32) + vec2(padding.float32, padding.float32)
    )
    
    # Left side
    result.lineTo(vec2(0, radii[dcTopLeft].float32) + vec2(padding.float32, padding.float32))
    
    # Top left corner
    let tlControl = vec2(0, 0)
    result.quadraticCurveTo(
      tlControl + vec2(padding.float32, padding.float32),
      vec2(radii[dcTopLeft].float32, 0) + vec2(padding.float32, padding.float32)
    )
    
    # Close the path
    result.lineTo(topRight + vec2(padding.float32, padding.float32))
  
  # Create the path for our rounded rectangle
  let path = createRoundedRectPath(innerWidth, innerHeight, radii, padding)
      
  # Draw the box
  if stroked:
    ctx.strokeStyle = fillStyle
    ctx.lineWidth = lineWidth
    ctx.stroke(path)
  else:
    ctx.fillStyle = fillStyle
    ctx.fill(path)
  
  # Apply inner shadow if requested
  if innerShadow or outerShadow or outerShadowFill:
    let shadow = img.shadow(
      offset = offset,
      spread = spread,
      blur = blur,
      color = shadowColor
    )

    let spath = createRoundedRectPath(innerWidth, innerHeight, radii, padding)

    let combined = newImage(totalSize, totalSize)
    let ctx = newContext(combined)
    if innerShadow:
      ctx.saveLayer()
      ctx.clip(spath, EvenOdd)
      ctx.drawImage(shadow, pos = vec2(0, 0))
      ctx.restore()
    if outerShadowFill:
      let spath = spath.copy()
      spath.rect(0, 0, totalSize.float32, totalSize.float32)
      ctx.saveLayer()
      ctx.clip(spath, EvenOdd)
      ctx.fillStyle = fillStyle
      ctx.rect(0, 0, totalSize.float32, totalSize.float32)
      ctx.fill()
      ctx.restore()
    if outerShadow:
      let spath = spath.copy()
      spath.rect(0, 0, totalSize.float32, totalSize.float32)
      ctx.saveLayer()
      ctx.clip(spath, EvenOdd)
      ctx.drawImage(shadow, pos = vec2(0, 0))
      ctx.restore()
    if innerShadowBorder:
      ctx.drawImage(img, pos = vec2(0, 0))
    return combined
  else:
    return img

proc clampRadii(radii: array[DirectionCorners, float32], rect: Rect): array[DirectionCorners, float32] =
  result = radii
  for r in result.mitems():
    r = max(1.0, min(r, min(rect.w / 2, rect.h / 2))).ceil()

proc fillRoundedRect*(ctx: Context, rect: Rect, color: Color, radii: array[DirectionCorners, float32]) =
  if rect.w <= 0 or rect.h <= -0:
    when defined(fidgetExtraDebugLogging):
      info "fillRoundedRect: too small: ", rect = rect
    return

  let
    w = rect.w.ceil()
    h = rect.h.ceil()
    radii = clampRadii(radii, rect)
    maxRadius = max(radii)
    rw = maxRadius
    rh = maxRadius

  let hash = hash((6118, (rw * 100).int, (rh * 100).int, hash(radii)))

  if true:
    # let stroked = stroked and lineWidth <= radius
    var hashes: array[DirectionCorners, Hash]
    for quadrant in DirectionCorners:
      let qhash = hash !& quadrant.int
      hashes[quadrant] = qhash

    if hashes[dcTopLeft] notin ctx.entries:
      let circle = generateCircleBox(radii, stroked = false)
      let patches = sliceToNinePatch(circle)
      # Store each piece in the atlas
      let patchArray = [
        dcTopLeft: patches.topLeft,
        dcTopRight: patches.topRight, 
        dcBottomRight: patches.bottomRight,
        dcBottomLeft: patches.bottomLeft,
      ]

      for quadrant in DirectionCorners:
        let img = patchArray[quadrant]
        ctx.putImage(hashes[quadrant], img)

    let
      xy = rect.xy
      offsets = [
        dcTopLeft: vec2(0, 0),
        dcTopRight: vec2(w - rw, 0),
        dcBottomRight: vec2(w - rw, h - rh),
        dcBottomLeft: vec2(0, h - rh),
      ]

    for corner in DirectionCorners:
      let
        uvRect = ctx.entries[hashes[corner]]
        wh = rect.wh * ctx.atlasSize.float32
        pt = xy + offsets[corner]

      ctx.drawUvRect(pt, pt + rw, uvRect.xy, uvRect.xy + uvRect.wh, color)

  let
    rrw = w - rw
    rrh = h - rh
    wrw = w - 2 * rw
    hrh = h - 2 * rh

  fillRect(ctx, rect(rect.x + rw, rect.y + rh, wrw, hrh), color)

  fillRect(ctx, rect(rect.x + rw, rect.y, wrw, rh), color)
  fillRect(ctx, rect(rect.x + rw, rect.y + rrh, wrw, rh), color)

  fillRect(ctx, rect(rect.x, rect.y + rh, rw, hrh), color)
  fillRect(ctx, rect(rect.x + rrw, rect.y + rh, rw, hrh), color)

proc strokeRoundedRect*(
    ctx: Context, rect: Rect, color: Color, weight: float32, radii: array[DirectionCorners, float32]
) =
  let fillStyle = rgba(255, 255, 255, 255)

  if rect.w <= 0 or rect.h <= -0:
    # when defined(fidgetExtraDebugLogging):
    #   echo "fillRoundedRect: too small: ", rect
    return

  let
    w = rect.w.ceil()
    h = rect.h.ceil()
    radii = clampRadii(radii, rect)
    maxRadius = max(radii)
    rw = maxRadius
    rh = maxRadius

  let hash =
    hash((6217, (rw * 100).int, (rh * 100).int, hash(radii), (weight * 100).int))

  if maxRadius > 0.0:
    var hashes: array[4, Hash]
    for quadrant in 1 .. 4:
      let qhash = hash !& quadrant
      hashes[quadrant - 1] = qhash

    if hashes[0] notin ctx.entries:
      # let radii = [radius.int, radius.int, radius.int, radius.int]
      let circle = generateCircleBox(radii, stroked = true, lineWidth = weight)
      let patches = sliceToNinePatch(circle)
      # Store each piece in the atlas
      let patchArray = [
        patches.topRight, 
        patches.topLeft,
        patches.bottomLeft,
        patches.bottomRight,
      ]

      for quadrant in 1 .. 4:
        let img = patchArray[quadrant - 1]
        ctx.putImage(hashes[quadrant - 1], img)

    let
      xy = rect.xy
      offsets = [vec2(w - rw, 0), vec2(0, 0), vec2(0, h - rh), vec2(w - rw, h - rh)]

    for corner in 0 .. 3:
      let
        uvRect = ctx.entries[hashes[corner]]
        wh = rect.wh * ctx.atlasSize.float32
        pt = xy + offsets[corner]

      ctx.drawUvRect(pt, pt + rw, uvRect.xy, uvRect.xy + uvRect.wh, color)

  block:
    let
      ww = weight
      rrw = w - ww
      rrh = h - ww
      wrw = w - 2 * rw
      hrh = h - 2 * rh

    fillRect(ctx, rect(rect.x + rw, rect.y, wrw, ww), color)
    fillRect(ctx, rect(rect.x + rw, rect.y + rrh, wrw, ww), color)

    fillRect(ctx, rect(rect.x, rect.y + rh, ww, hrh), color)
    fillRect(ctx, rect(rect.x + rrw, rect.y + rh, ww, hrh), color)

proc line*(ctx: Context, a: Vec2, b: Vec2, weight: float32, color: Color) =
  let hash = hash((2345, a, b, (weight * 100).int, hash(color)))

  let
    w = ceil(abs(b.x - a.x)).int
    h = ceil(abs(a.y - b.y)).int
    pos = vec2(min(a.x, b.x), min(a.y, b.y))

  if w == 0 or h == 0:
    return

  if hash notin ctx.entries:
    let
      image = newImage(w, h)
      c = newContext(image)
    c.fillStyle = rgba(255, 255, 255, 255)
    c.lineWidth = weight
    c.strokeSegment(segment(a - pos, b - pos))
    ctx.putImage(hash, image)
  let
    uvRect = ctx.entries[hash]
    wh = vec2(w.float32, h.float32) * ctx.atlasSize.float32
  ctx.drawUvRect(
    pos, pos + vec2(w.float32, h.float32), uvRect.xy, uvRect.xy + uvRect.wh, color
  )

proc linePolygon*(ctx: Context, poly: seq[Vec2], weight: float32, color: Color) =
  for i in 0 ..< poly.len:
    ctx.line(poly[i], poly[(i + 1) mod poly.len], weight, color)

proc clearMask*(ctx: Context) =
  ## Sets mask off (actually fills the mask with white).
  assert ctx.frameBegun == true, "ctx.beginFrame has not been called."

  ctx.draw()

  ctx.setUpMaskFramebuffer()

  glClearColor(1, 1, 1, 1)
  glClear(GL_COLOR_BUFFER_BIT)

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc beginMask*(ctx: Context) =
  ## Starts drawing into a mask.
  assert ctx.frameBegun == true, "ctx.beginFrame has not been called."
  assert ctx.maskBegun == false, "ctx.beginMask has already been called."
  ctx.maskBegun = true

  ctx.draw()

  inc ctx.maskTextureWrite
  ctx.maskTextureRead = ctx.maskTextureWrite - 1
  if ctx.maskTextureWrite >= ctx.maskTextures.len:
    ctx.addMaskTexture(ctx.frameSize)

  ctx.setUpMaskFramebuffer()
  glViewport(0, 0, ctx.frameSize.x.GLint, ctx.frameSize.y.GLint)

  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)

  ctx.activeShader = ctx.maskShader

proc endMask*(ctx: Context) =
  ## Stops drawing into the mask.
  assert ctx.maskBegun == true, "ctx.maskBegun has not been called."
  ctx.maskBegun = false

  ctx.draw()

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  ctx.maskTextureRead = ctx.maskTextureWrite

  ctx.activeShader = ctx.atlasShader

proc popMask*(ctx: Context) =
  ctx.draw()

  dec ctx.maskTextureWrite
  ctx.maskTextureRead = ctx.maskTextureWrite

proc beginFrame*(ctx: Context, frameSize: Vec2, proj: Mat4) =
  ## Starts a new frame.
  assert ctx.frameBegun == false, "ctx.beginFrame has already been called."
  ctx.frameBegun = true

  ctx.proj = proj

  if ctx.maskTextures[0].width != frameSize.x.int32 or
      ctx.maskTextures[0].height != frameSize.y.int32:
    # Resize all of the masks.
    ctx.frameSize = frameSize
    for i in 0 ..< ctx.maskTextures.len:
      ctx.maskTextures[i].width = frameSize.x.int32
      ctx.maskTextures[i].height = frameSize.y.int32
      if i > 0:
        # Never resize the 0th mask because its just white.
        bindTextureData(ctx.maskTextures[i].addr, nil)

  glViewport(0, 0, ctx.frameSize.x.GLint, ctx.frameSize.y.GLint)

  ctx.clearMask()

proc beginFrame*(ctx: Context, frameSize: Vec2) =
  beginFrame(
    ctx, frameSize, ortho[float32](0.0, frameSize.x, frameSize.y, 0, -1000.0, 1000.0)
  )

proc endFrame*(ctx: Context) =
  ## Ends a frame.
  assert ctx.frameBegun == true, "ctx.beginFrame was not called first."
  assert ctx.maskTextureRead == 0, "Not all masks have been popped."
  assert ctx.maskTextureWrite == 0, "Not all masks have been popped."
  ctx.frameBegun = false

  ctx.draw()

proc translate*(ctx: Context, v: Vec2) =
  ## Translate the internal transform.
  ctx.mat = ctx.mat * translate(vec3(v))

proc rotate*(ctx: Context, angle: float32) =
  ## Rotates the internal transform.
  ctx.mat = ctx.mat * rotateZ(angle)

proc scale*(ctx: Context, s: float32) =
  ## Scales the internal transform.
  ctx.mat = ctx.mat * scale(vec3(s))

proc scale*(ctx: Context, s: Vec2) =
  ## Scales the internal transform.
  ctx.mat = ctx.mat * scale(vec3(s.x, s.y, 1))

proc saveTransform*(ctx: Context) =
  ## Pushes a transform onto the stack.
  ctx.mats.add ctx.mat

proc restoreTransform*(ctx: Context) =
  ## Pops a transform off the stack.
  ctx.mat = ctx.mats.pop()

proc clearTransform*(ctx: Context) =
  ## Clears transform and transform stack.
  ctx.mat = mat4()
  ctx.mats.setLen(0)

proc fromScreen*(ctx: Context, windowFrame: Vec2, v: Vec2): Vec2 =
  ## Takes a point from screen and translates it to point inside the current transform.
  (ctx.mat.inverse() * vec3(v.x, windowFrame.y - v.y, 0)).xy

proc toScreen*(ctx: Context, windowFrame: Vec2, v: Vec2): Vec2 =
  ## Takes a point from current transform and translates it to screen.
  result = (ctx.mat * vec3(v.x, v.y, 1)).xy
  result.y = -result.y + windowFrame.y

var shadowCache: Table[Hash, Image] = initTable[Hash, Image]()

proc fillRoundedRectWithShadow*(
    ctx: Context,
    rect: Rect,
    radii: array[DirectionCorners, float32],
    shadowX, shadowY, shadowBlur, shadowSpread: float32,
    shadowColor: Color,
    innerShadow = false,
) =
  ## Draws a rounded rectangle with a shadow underneath using 9-patch technique
  ## The shadow is drawn with padding around the main rectangle
  if rect.w <= 0 or rect.h <= 0:
    return
    
  # First, draw the shadow
  # Generate shadow key for caching
  proc getShadowKey(blur: float32, spread: float32, radius: float32, innerShadow: bool): Hash =
    hash((7723, (blur * 1).int, (spread * 1).int, (radius * 1).int, innerShadow))

  let 
    radii = clampRadii(radii, rect)
    maxRadius = max(radii)
    shadowBlurSizeLimit = 14.0
    shadowSpreadLimit = 14.0
    radiusLimit = maxRadius
    shadowBlurSize = shadowBlur
    shadowSpread = shadowSpread
    shadowKey = getShadowKey(shadowBlurSize, shadowSpread, radiusLimit, innerShadow)
  
  var ninePatchHashes: array[8, Hash]
  for i in 0..7:
    ninePatchHashes[i] = shadowKey !& i

  # Check if we've already generated this shadow
  let shadowKeyBase = shadowKey !& 0
  let newSize = max(shadowBlur.int + shadowSpread.int + maxRadius.int, 2)

  if shadowKeyBase notin ctx.entries:
    var shadowImg: Image
    let mainKey = getShadowKey(shadowBlurSizeLimit, shadowSpreadLimit, radiusLimit, innerShadow)
    # Generate shadow image
    if mainKey notin shadowCache:
      echo "generating main shadow image: ", mainKey, " blur: ", shadowBlurSizeLimit.round(2), " spread: ", shadowSpreadLimit.round(2), " radius: ", radiusLimit.round(2), " ", innerShadow
      if innerShadow:
        let mainImg = generateCircleBox(
          radii = radii,
          offset = vec2(0, 0),
          spread = shadowSpreadLimit,
          blur = shadowBlurSizeLimit,
          stroked = true,
          lineWidth = 1.0,
          innerShadow = true,
          outerShadow = false,
          innerShadowBorder = false,
          outerShadowFill = true,
        )
        # mainImg.writeFile("examples/renderer-shadowImage-" & $innerShadow & ".png")
        shadowCache[mainKey] = mainImg
      else:
        let mainImg = generateCircleBox(
          radii = radii,
          offset = vec2(0, 0),
          spread = shadowSpreadLimit,
          blur = shadowBlurSizeLimit,
          stroked = false,
          lineWidth = 1.0,
          outerShadow = true,
          innerShadow = false,
          innerShadowBorder = true,
          outerShadowFill = false,
        )
        # mainImg.writeFile("examples/renderer-shadowImage-" & $innerShadow & ".png")
        shadowCache[mainKey] = mainImg
    shadowImg = shadowCache[mainKey].resize(newSize, newSize)

    # Slice it into 9-patch pieces
    let patches = sliceToNinePatch(shadowImg)

    # Store each piece in the atlas
    let patchArray = [
      patches.topLeft, patches.topRight, 
      patches.bottomLeft, patches.bottomRight,
      patches.top, patches.right, 
      patches.bottom, patches.left
    ]

    for i in 0..7:
      ninePatchHashes[i] = shadowKey !& i
      ctx.putImage(ninePatchHashes[i], patchArray[i])

  var 
    totalPadding = int(shadowBlur+shadowSpread) - 1
    corner = maxRadius + totalPadding.float32 + 1

  if innerShadow:
    totalPadding = int(shadowBlur+shadowSpread) - 1
    corner = 2*(shadowBlur+shadowSpread) + 1

  let
    sbox = rect(
      rect.x - totalPadding.float32 + shadowX,
      rect.y - totalPadding.float32 + shadowY,
      rect.w + 2 * totalPadding.float32,
      rect.h + 2 * totalPadding.float32
    )
    halfW = sbox.w / 2
    halfH = sbox.h / 2
    centerX = sbox.x + halfW
    centerY = sbox.y + halfH

  # Draw the corners
  let 
    topLeft = rect(sbox.x, sbox.y, corner, corner)
    topRight = rect(sbox.x + sbox.w - corner, sbox.y, corner, corner)
    bottomLeft = rect(sbox.x, sbox.y + sbox.h - corner, corner, corner)
    bottomRight = rect(sbox.x + sbox.w - corner, sbox.y + sbox.h - corner, corner, corner)
  
  # Draw corners
  ctx.drawImageAdj(ninePatchHashes[0], topLeft.xy, shadowColor, topLeft.wh)
  ctx.drawImageAdj(ninePatchHashes[1], topRight.xy, shadowColor, topRight.wh)
  ctx.drawImageAdj(ninePatchHashes[2], bottomLeft.xy, shadowColor, bottomLeft.wh)
  ctx.drawImageAdj(ninePatchHashes[3], bottomRight.xy, shadowColor, bottomRight.wh)
  
  # Draw edges
  # Top edge (stretched horizontally)
  let topEdge = rect(sbox.x + corner, sbox.y, sbox.w - 2 * corner, corner)
  ctx.drawImageAdj(ninePatchHashes[4], topEdge.xy, shadowColor, topEdge.wh)
  let rightEdge = rect( sbox.x + sbox.w - corner, sbox.y + corner, corner, sbox.h - 2 * corner)
  ctx.drawImageAdj(ninePatchHashes[5], rightEdge.xy, shadowColor*1.0, rightEdge.wh)
  let bottomEdge = rect( sbox.x + corner, sbox.y + sbox.h - corner, sbox.w - 2 * corner, corner)
  ctx.drawImageAdj(ninePatchHashes[6], bottomEdge.xy, shadowColor*1.0, bottomEdge.wh)
  let leftEdge = rect( sbox.x, sbox.y + corner, corner, sbox.h - 2 * corner)
  ctx.drawImageAdj(ninePatchHashes[7], leftEdge.xy, shadowColor*1.0, leftEdge.wh)
  
  # Center (stretched both ways)
  let center = rect(sbox.x + corner, sbox.y + corner, sbox.w - 2 * corner, sbox.h - 2 * corner)
  if not innerShadow:
    ctx.fillRect(center, shadowColor)
