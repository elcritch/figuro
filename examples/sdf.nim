import std/math
import pixie, vmath, pixie/simd

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

proc signedRoundedBox*(image: Image, center: Vec2, b: Vec2, r: Vec4, pos: ColorRGBA, neg: ColorRGBA) {.hasSimd, raises: [].} =
  ## Signed distance function for a rounded box
  ## p: point to test
  ## b: box half-extents (width/2, height/2)
  ## r: corner radii as Vec4 (x=top-right, y=bottom-right, z=bottom-left, w=top-left)
  ## Returns: signed distance (negative inside, positive outside)
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let p = vec2(x.float32, y.float32) - center
      let sd = sdRoundedBox(p, b, r)
      let color = if sd < 0.0: pos else: neg
      let idx = image.dataIndex(x, y)
      image.data[idx] = color.rgbx()

proc main() =
  let image = newImage(400, 400)

  signedRoundedBox(image,
                    center = vec2(200.0, 200.0),
                    b = vec2(100.0, 100.0),
                    r = vec4(0.0, 20.0, 50.0, 70.0),
                    pos = rgba(255, 0, 0, 255),
                    neg = rgba(0, 0, 255, 255))

  image.writeFile("tests/rounded_box.png")

main()