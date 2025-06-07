import std/math, std/monotimes, std/times
import pixie, vmath, pixie/simd

import sdftypes

# Import NEON SIMD implementation when available
# when not defined(pixieNoSimd) and (defined(arm) or defined(arm64) or defined(aarch64)):
#   import simd/sdneon

proc invert*(image: Image) {.hasSimd, raises: [].} =
  ## Inverts all of the colors and alpha.
  for i in 0 ..< image.data.len:
    var rgbx = image.data[i]
    rgbx.r = 255 - rgbx.r
    rgbx.g = 255 - rgbx.g
    rgbx.b = 255 - rgbx.b
    rgbx.a = 255 - rgbx.a
    image.data[i] = rgbx

proc sdRoundedBox*(p: Vec2, b: Vec2, r: Vec4): float32 {.inline.} =
  ## Signed distance function for a rounded box
  ## p: point to test
  ## b: box half-extents (width/2, height/2)
  ## r: corner radii as Vec4 (x=top-right, y=bottom-right, z=bottom-left, w=top-left)
  ## Returns: signed distance (negative inside, positive outside)
  var cornerRadius = r
  
  # Select appropriate corner radius based on quadrant
  cornerRadius.xy = if p.x > 0.0: r.xy else: r.zw
  cornerRadius.x = if p.y > 0.0: cornerRadius.x else: cornerRadius.y
  
  # Calculate distance
  let q = abs(p) - b + vec2(cornerRadius.x, cornerRadius.x)
  
  result = min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0, 0.0))) - cornerRadius.x

proc signedRoundedBox*(
    image: Image,
    center: Vec2,
    wh: Vec2,
    r: Vec4,
    pos: ColorRGBA,
    neg: ColorRGBA,
    factor: float32 = 2.2,
    mode: SDFMode = sdfModeFeatherInv
) {.hasSimd, raises: [].} =
  ## Signed distance function for a rounded box
  ## p: point to test
  ## b: box half-extents (width/2, height/2)
  ## r: corner radii as Vec4 (x=top-right, y=bottom-right, z=bottom-left, w=top-left)
  ## Returns: signed distance (negative inside, positive outside)
  let
    b = wh / 2.0
    s = 2.2
    s2 = 2 * s^2

  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let p = vec2(x.float32, y.float32) - center
      let sd = sdRoundedBox(p, b, r)
      var c: ColorRGBA = if sd < 0.0: pos else: neg
      case mode:
      of sdfModeClip:
        discard
      of sdfModeFeather:
        c.a = uint8(max(0.0, min(255, (factor*sd) + 127)))
      of sdfModeFeatherInv:
        c.a = 255 - uint8(max(0.0, min(255, (factor*sd) + 127)))
      of sdfModeFeatherGaussian:
        let sd = sd / factor
        let f = 1 / sqrt(PI * s2) * exp(-1 * sd^2 / s2)
        c.a = uint8(f * 255)
      let idx = image.dataIndex(x, y)
      image.data[idx] = c.rgbx()

template timeIt(name: string, body: untyped) =
  let start = getMonoTime()
  body
  let stop = getMonoTime()
  echo name, ": ", inMilliseconds(stop - start), " ms"

proc main() =
  let image = newImage(300, 300)
  let center = vec2(150.0, 150.0)
  let pos = rgba(255, 0, 0, 255)
  let neg = rgba(0, 0, 255, 255)
  let corners = vec4(0.0, 10.0, 20.0, 30.0)
  let wh = vec2(200.0, 200.0)

  timeIt "base":
    let rect = newImage(300, 300)
    let ctx = newContext(rect)
    ctx.fillStyle = pos
    ctx.fillRoundedRect(rect(center - wh/2, wh), 20.0)
    let shadow = rect.shadow(
      offset = vec2(0, 0),
      spread = 0.0,
      blur = 20.0,
      color = neg
      )
    
    image.draw(shadow)
    image.draw(rect)

  image.writeFile("tests/rounded_box_base.png")

  timeIt "clip":
    signedRoundedBox(image,
                    center = center,
                    wh = wh,
                    r = corners,
                    pos = pos,
                    neg = neg,
                    mode = sdfModeClip)

  image.writeFile("tests/rounded_box.png")

  timeIt "feather":
    signedRoundedBox(image,
                    center = center,
                    wh = wh,
                    r = corners,
                    pos = pos,
                    neg = neg,
                    mode = sdfModeFeather)

  image.writeFile("tests/rounded_box_feather.png")

  timeIt "featherInv":
    signedRoundedBox(image,
                    center = center,
                    wh = wh,
                    r = corners,
                    pos = pos,
                    neg = neg,
                    mode = sdfModeFeatherInv)

  image.writeFile("tests/rounded_box_feather_inv.png")

  timeIt "featherGaussian":
    signedRoundedBox(image,
                    center = center,
                    wh = wh,
                    r = corners,
                    pos = pos,
                    neg = neg,
                    mode = sdfModeFeatherGaussian)

  image.writeFile("tests/rounded_box_feather_gaussian.png")

for i in 0 ..< 3:
  main()
