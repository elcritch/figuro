import std/[hashes, tables, times]
import pkg/chroma
import pkg/pixie
import pkg/boxy

type
  RContext* = object
    boxy*: Boxy
    entries*: TableRef[Hash, string]

func `*`*(m: Mat4, v: Vec2): Vec2 =
  (m * vec3(v.x, v.y, 0.0)).xy

template imgKey*(ctx: RContext, hash: Hash): string =
  ctx.entries[hash]
template imgKey*(ctx: RContext, key: string): string =
  key

proc putImage*(ctx: RContext, hash: Hash, img: Image) =
  let hkey = $hash
  ctx.entries[hash] = hkey
  ctx.boxy.addImage(hkey, img)

proc drawImage*(ctx: RContext, key: Hash | string, pos: Rect | Vec2, color: Color) =
  ctx.boxy.drawImage(ctx.imgKey(hash), pos, color)

proc generateCorner(
    radius: int,
    quadrant: range[1..4],
    stroked: bool,
    lineWidth: float32 = 0'f32,
    fillStyle = rgba(255, 255, 255, 255)
): Image =
  const s = 4.0/3.0 * (sqrt(2.0) - 1.0)
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
      let bl = vec2(0, y - lineWidth/2)
      let tr = vec2(x - lineWidth/2, 0)
      path.moveTo(bl)
      path.bezierCurveTo(blc, trc, tr)
    else:
      path.moveTo(tr)
      path.lineTo(tl)
      path.lineTo(bl)
      path.bezierCurveTo(blc, trc, tr)

    case quadrant:
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
    drawImpl(ctx1, doStroke=false)
  else:
    let ctx2 = newContext(image)
    ctx2.strokeStyle = fillStyle
    ctx2.lineCap = SquareCap
    ctx2.lineWidth = lineWidth
    drawImpl(ctx2, doStroke=true)

  result = image

proc fillRect*(
    ctx: RContext,
    rect: Rect,
    color: Color,
) =
  ctx.boxy.drawRect(rect, color)

proc fillRoundedRect*(
    ctx: RContext,
    rect: Rect,
    color: Color,
    radius: float32
) =
  if rect.w <= 0 or rect.h <= -0:
    when defined(fidgetExtraDebugLogging):
      echo "fillRoundedRect: too small: ", rect
    return

  let
    w = rect.w.ceil()
    h = rect.h.ceil()
    radius = min(radius, min(rect.w/2, rect.h/2)).ceil()
    rw = radius
    rh = radius

  let hash = hash((
    6118,
    (rw*100).int, (rh*100).int,
    (radius*100).int,
  ))

  if radius > 0.0:
    # let stroked = stroked and lineWidth <= radius
    var hashes: array[4, Hash]
    for quadrant in 1..4:
      let qhash = hash !& quadrant
      hashes[quadrant-1] = qhash
      if qhash notin ctx.entries:
        let img = generateCorner(radius.int, quadrant, false, 0.0, rgba(255, 255, 255, 255))
        ctx.putImage(qhash, img)

    let
      xy = rect.xy 
      offsets = [vec2(w-rw, 0), vec2(0, 0), vec2(0, h-rh), vec2(w-rw, h-rh)]

    for corner in 0..3:
      let
        pt = xy + offsets[corner]
        cr = rect(xy.x, xy.y, pt.x, pt.y) 
      ctx.boxy.drawImage(ctx.imgKey(hashes[corner]), cr)
      # let
      #   uvRect = ctx.entries[hashes[corner]]
      #   wh = rect.wh * ctx.atlasSize.float32
      #   pt = xy + offsets[corner]
      
      # ctx.drawUvRect(pt, pt + rw,
      #               uvRect.xy, uvRect.xy + uvRect.wh,
      #               color)

  let
    rrw = w-rw
    rrh = h-rh
    wrw = w-2*rw
    hrh = h-2*rh
  
  fillRect(ctx, rect(rect.x+rw, rect.y+rh, wrw, hrh), color)

  fillRect(ctx, rect(rect.x+rw, rect.y,     wrw, rh), color)
  fillRect(ctx, rect(rect.x+rw, rect.y+rrh, wrw, rh), color)

  fillRect(ctx, rect(rect.x, rect.y+rh,     rw, hrh), color)
  fillRect(ctx, rect(rect.x+rrw, rect.y+rh, rw, hrh), color)

proc strokeRoundedRect*(
    ctx: RContext,
    rect: Rect,
    color: Color,
    weight: float32,
    radius: float32,
) =
  let
    fillStyle = rgba(255, 255, 255, 255)
  
  if rect.w <= 0 or rect.h <= -0:
    when defined(fidgetExtraDebugLogging):
      echo "fillRoundedRect: too small: ", rect
    return

  let
    w = rect.w.ceil()
    h = rect.h.ceil()
    radius = min(radius, min(rect.w/2, rect.h/2)).ceil()
    rw = radius
    rh = radius

  let hash = hash((
    6217,
    (rw*100).int, (rh*100).int,
    (radius*100).int,
    (weight*100).int,
  ))

  if radius > 0.0:
    # let stroked = stroked and lineWidth <= radius
    var hashes: array[4, Hash]
    for quadrant in 1..4:
      let qhash = hash !& quadrant
      hashes[quadrant-1] = qhash
      if qhash notin ctx.entries:
        let img = generateCorner(radius.int, quadrant, true, weight, fillStyle)
        ctx.putImage(qhash, img)

    let
      xy = rect.xy
      offsets = [vec2(w-rw, 0), vec2(0, 0), vec2(0, h-rh), vec2(w-rw, h-rh)]

    for corner in 0..3:
      let
        pt = xy + offsets[corner]
        cr = rect(xy.x, xy.y, pt.x, pt.y) 
      ctx.boxy.drawImage(ctx.imgKey(hashes[corner]), cr)
      # let
      #   uvRect = ctx.entries[hashes[corner]]
      #   wh = rect.wh * ctx.atlasSize.float32
      #   pt = xy + offsets[corner]
      
      # ctx.drawUvRect(pt, pt + rw,
      #               uvRect.xy, uvRect.xy + uvRect.wh,
      #               color)

  block:
    let
      ww = weight
      rrw = w-ww
      rrh = h-ww
      wrw = w-2*rw
      hrh = h-2*rh
    
    fillRect(ctx, rect(rect.x+rw, rect.y,     wrw, ww), color)
    fillRect(ctx, rect(rect.x+rw, rect.y+rrh, wrw, ww), color)

    fillRect(ctx, rect(rect.x, rect.y+rh,     ww, hrh), color)
    fillRect(ctx, rect(rect.x+rrw, rect.y+rh, ww, hrh), color)

when false:
  proc strokeRoundedRect*(
    ctx: RContext, rect: Rect, color: Color, weight: float32, radius: float32
  ) =
      if rect.w <= 0 or rect.h <= -0:
        when defined(fidgetExtraDebugLogging): echo "strokeRoundedRect: too small: ", rect
        return

      let radius = min(radius, min(rect.w/2, rect.h/2))
      # TODO: Make this a 9 patch
      let hash = hash((
        8349,
        rect.w.int,
        rect.h.int,
        (weight*100).int,
        (radius*100).int
      ))

      let
        w = ceil(rect.w).int
        h = ceil(rect.h).int
      if hash notin ctx.entries:
        let
          image = newImage(w, h)
          c = newRContext(image)
        c.fillStyle = rgba(255, 255, 255, 255)
        c.lineWidth = weight
        c.strokeStyle = color
        c.strokeRoundedRect(
          rect(weight / 2, weight / 2, rect.w - weight, rect.h - weight),
          radius
        )
        echo "strokeRoundedRect: ", hash
        ctx.putImage(hash, image, true)
      let
        uvRect = ctx.entries[hash]
        wh = rect.wh * ctx.atlasSize.float32
      ctx.drawUvRect(
        rect.xy,
        rect.xy + vec2(w.float32, h.float32),
        uvRect.xy,
        uvRect.xy + uvRect.wh,
        color
      )

# proc line*(
#   ctx: RContext, a: Vec2, b: Vec2, weight: float32, color: Color
# ) =
#   let hash = hash((
#     2345,
#     a,
#     b,
#     (weight*100).int,
#     hash(color)
#   ))

#   let
#     w = ceil(abs(b.x - a.x)).int
#     h = ceil(abs(a.y - b.y)).int
#     pos = vec2(min(a.x, b.x), min(a.y, b.y))

#   if w == 0 or h == 0:
#     return

#   if hash notin ctx.entries:
#     let
#       image = newImage(w, h)
#       c = newRContext(image)
#     c.fillStyle = rgba(255, 255, 255, 255)
#     c.lineWidth = weight
#     c.strokeSegment(segment(a - pos, b - pos))
#     echo "line: ", hash
#     ctx.putImage(hash, image, true)
#   let
#     uvRect = ctx.entries[hash]
#     wh = vec2(w.float32, h.float32) * ctx.atlasSize.float32
#   ctx.drawUvRect(
#     pos,
#     pos + vec2(w.float32, h.float32),
#     uvRect.xy,
#     uvRect.xy + uvRect.wh,
#     color
#   )

# proc linePolygon*(
#   ctx: RContext, poly: seq[Vec2], weight: float32, color: Color
# ) =
#   for i in 0 ..< poly.len:
#     ctx.line(poly[i], poly[(i+1) mod poly.len], weight, color)


# proc fromScreen*(ctx: RContext, windowFrame: Vec2, v: Vec2): Vec2 =
#   ## Takes a point from screen and translates it to point inside the current transform.
#   (ctx.mat.inverse() * vec3(v.x, windowFrame.y - v.y, 0)).xy

# proc toScreen*(ctx: RContext, windowFrame: Vec2, v: Vec2): Vec2 =
#   ## Takes a point from current transform and translates it to screen.
#   result = (ctx.mat * vec3(v.x, v.y, 1)).xy
#   result.y = -result.y + windowFrame.y
