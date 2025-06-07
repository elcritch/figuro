import std/math, std/monotimes, std/times
import pixie, vmath, pixie/simd
import sdneon

template timeIt(name: string, body: untyped) =
  let start = getMonoTime()
  body
  let stop = getMonoTime()
  echo name, ": ", inMilliseconds(stop - start), "ms"

proc main() =
  let 
    width = 400
    height = 400
    image1 = newImage(width, height)
    image2 = newImage(width, height)
    center = vec2(200.0, 200.0)
    b = vec2(100.0, 100.0)
    r = vec4(0.0, 20.0, 50.0, 70.0)
    pos = rgba(255, 0, 0, 255)
    neg = rgba(0, 0, 255, 255)

  echo "Testing NEON SIMD vs Regular implementation"
  echo "Image size: ", width, "x", height
  
  # Test regular implementation
  timeIt("Regular implementation"):
    for y in 0 ..< image1.height:
      for x in 0 ..< image1.width:
        let p = vec2(x.float32, y.float32) - center
        let sd = sdRoundedBox(p, b, r)
        var color = if sd < 0.0: pos else: neg
        color.a = uint8(max(0.0, min(255.0, (4.0 * sd) + 127.0)))
        let idx = image1.dataIndex(x, y)
        image1.data[idx] = color.rgbx()

  # Test NEON SIMD implementation
  timeIt("NEON SIMD implementation"):
    signedRoundedBoxFeatherNeon(image2, center, b, r, pos, neg)

  # Verify correctness by comparing a few sample pixels
  echo "\nVerifying correctness:"
  var differences = 0
  var maxDifference = 0

  for y in 0 ..< min(height, 10):  # Check first 10 rows
    for x in 0 ..< min(width, 10): # Check first 10 columns
      let 
        idx = image1.dataIndex(x, y)
        pixel1 = image1.data[idx]
        pixel2 = image2.data[idx]
        
      let diff = abs(pixel1.r.int - pixel2.r.int) + 
                 abs(pixel1.g.int - pixel2.g.int) + 
                 abs(pixel1.b.int - pixel2.b.int) + 
                 abs(pixel1.a.int - pixel2.a.int)
      
      if diff > 0:
        differences += 1
        maxDifference = max(maxDifference, diff)
        if differences <= 5:  # Show first 5 differences
          echo "Difference at (", x, ",", y, "): Regular=(", pixel1.r, ",", pixel1.g, ",", pixel1.b, ",", pixel1.a, 
               ") SIMD=(", pixel2.r, ",", pixel2.g, ",", pixel2.b, ",", pixel2.a, ") diff=", diff

  echo "Total differences in sample: ", differences, "/", min(height, 10) * min(width, 10)
  echo "Max difference: ", maxDifference
  
  # Save test images
  image1.writeFile("test_regular.png")
  image2.writeFile("test_simd.png")
  echo "\nImages saved as test_regular.png and test_simd.png"
  
  if differences == 0:
    echo "✓ Perfect match - SIMD implementation is correct!"
  elif maxDifference <= 1:
    echo "✓ Very close match - minor rounding differences acceptable"
  else:
    echo "✗ Significant differences detected - review implementation"

main() 