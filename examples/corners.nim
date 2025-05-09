import pixie, pixie/simd

type
  DirectionCorners* = enum
    dcTopLeft
    dcTopRight
    dcBottomRight
    dcBottomLeft

proc generateCorner(
    radius: int,
    quadrant: DirectionCorners,
    stroked: bool,
    lineWidth: float32 = 0'f32,
    fillStyle = rgba(255, 255, 255, 255),
    innerShadow = false,
    shadowColor = rgba(255, 0, 0, 255),
    offset = vec2(0, 0),
    spread = 0.0,
    blur = 0.0,
): Image =
  const s = 4.0 / 3.0 * (sqrt(2.0) - 1.0)
  let
    x = radius.toFloat
    y = radius.toFloat
    r = radius.toFloat - lineWidth

    tl = vec2(0, 0)
    tr = vec2(x, 0)
    bl = vec2(0, y)
    br = vec2(x, y)
    trc = tr + vec2(0, r * s)
    blc = bl + vec2(r * s, 0)

  template drawImpl(ctx: untyped, doStroke: bool, lineWidth: float32) =
    let path = newPath()
    if doStroke:
      let bl = vec2(0, y - lineWidth / 2)
      let tr = vec2(x - lineWidth / 2, 0)
      path.moveTo(bl)
      path.bezierCurveTo(blc, trc, tr)
    else:
      path.moveTo(tr)
      path.lineTo(tl)
      path.lineTo(bl)
      path.bezierCurveTo(blc, trc, tr)

    case quadrant
    of dcTopLeft: # TL
      ctx.rotate(180 * PI / 180)
      ctx.translate(-br)
    of dcTopRight: # TR
      ctx.rotate(270 * PI / 180)
      ctx.translate(-tr)
    of dcBottomLeft: # BL
      ctx.rotate(90 * PI / 180)
      ctx.translate(-bl)
    of dcBottomRight: # BR
      discard

    if doStroke:
      ctx.stroke(path)
    else:
      ctx.fill(path)

  let corner = newImage(radius, radius)

  let ctx2 = newContext(corner)
  ctx2.fillStyle = fillStyle
  ctx2.strokeStyle = fillStyle
  ctx2.lineCap = SquareCap
  ctx2.lineWidth = lineWidth
  drawImpl(ctx2, doStroke = stroked, lineWidth = lineWidth)

  let image = newImage(radius, radius)
  
  if innerShadow:
    let shadow = corner.shadow(
      offset = offset,
      spread = spread,
      blur = blur,
      color = shadowColor
    )
    image.draw(shadow)

  image.draw(corner)

  if innerShadow:
    let circleSolid = newImage(radius, radius)
    let ctx3 = newContext(circleSolid)
    ctx3.fillStyle = fillStyle
    drawImpl(ctx3, doStroke = false, lineWidth = lineWidth)
    image.draw(circleSolid, blendMode = MaskBlend)

  result = image


for i in DirectionCorners:
  let img = generateCorner(30, i, stroked = true,
              lineWidth = 3, innerShadow = true,
              spread = 1, blur = 10,
              )
  img.writeFile("examples/corner" & $i & ".png")
