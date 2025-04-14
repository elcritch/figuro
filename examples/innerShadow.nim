import pixie, pixie/simd

proc generateCorner(
    radius: int,
    quadrant: range[1 .. 4],
    stroked: bool,
    lineWidth: float32 = 0'f32,
    fillStyle = rgba(255, 255, 255, 255),
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

  template drawImpl(ctx: untyped, doStroke: bool) =
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
    of 1:
      ctx.rotate(270 * PI / 180)
      ctx.translate(-tr)
    of 2:
      ctx.rotate(180 * PI / 180)
      ctx.translate(-br)
    of 3:
      ctx.rotate(90 * PI / 180)
      ctx.translate(-bl)
    of 4:
      discard

    if doStroke:
      ctx.stroke(path)
    else:
      ctx.fill(path)

  let image = newImage(radius, radius)

  if not stroked:
    let ctx1 = newContext(image)
    ctx1.fillStyle = fillStyle
    drawImpl(ctx1, doStroke = false)
  else:
    let ctx2 = newContext(image)
    ctx2.strokeStyle = fillStyle
    ctx2.lineCap = SquareCap
    ctx2.lineWidth = lineWidth
    drawImpl(ctx2, doStroke = true)

  result = image

# shadowImage.invert()
let corner = generateCorner(
  radius = 40,
  quadrant = 1,
  stroked = true,
  lineWidth = 3.0'f32
)

let corner2 = generateCorner(
  radius = 40 + 3,
  quadrant = 1,
  stroked = true,
  lineWidth = 6.0'f32
)

let shadow = corner.shadow(
  offset = vec2(0, 0),
  spread = 2.0'f32,
  blur = 8.0'f32,
  color = rgba(255, 255, 255, 255)
)

let image = newImage(shadow.width, shadow.height)
image.draw(shadow)
image.draw(corner)
# image.draw(corner2, blendMode = MaskBlend)

image.writeFile("examples/corner2.png")
