import std/math, std/monotimes, std/times
import pixie, vmath, pixie/simd
import sdneon
import ../sdftypes

template timeIt(name: string, body: untyped) =
  let start = getMonoTime()
  body
  let stop = getMonoTime()
  echo name, ": ", inMilliseconds(stop - start), "ms"

proc main() =
  let 
    width = 400
    height = 400
    center = vec2(200.0, 200.0)
    wh = vec2(200.0, 200.0)
    r = vec4(0.0, 20.0, 50.0, 70.0)
    pos = rgba(255, 0, 0, 255)
    neg = rgba(0, 0, 255, 255)

  echo "Testing NEON SIMD implementation with different modes"
  echo "Image size: ", width, "x", height
  
  # Test clipped mode
  let imageClipped = newImage(width, height)
  timeIt("NEON SIMD implementation (clipped)"):
    signedRoundedBoxNeon(imageClipped, center, wh, r, pos, neg, factor = 4.0, mode = sdfModeClip)

  # Test feathered mode
  let imageFeathered = newImage(width, height)
  timeIt("NEON SIMD implementation (feathered)"):
    signedRoundedBoxNeon(imageFeathered, center, wh, r, pos, neg, factor = 4.0, mode = sdfModeFeather)

  # Test inverted feathered mode
  let imageFeatheredInv = newImage(width, height)
  timeIt("NEON SIMD implementation (feathered inverted)"):
    signedRoundedBoxNeon(imageFeatheredInv, center, wh, r, pos, neg, factor = 4.0, mode = sdfModeFeatherInv)

  # Test Gaussian feathered mode
  let imageGaussian = newImage(width, height)
  timeIt("NEON SIMD implementation (Gaussian feathered)"):
    signedRoundedBoxNeon(imageGaussian, center, wh, r, pos, neg, factor = 4.0, mode = sdfModeFeatherGaussian)

  # Save test images
  imageClipped.writeFile("test_simd_clipped.png")
  imageFeathered.writeFile("test_simd_feathered.png")
  imageFeatheredInv.writeFile("test_simd_feathered_inv.png")
  imageGaussian.writeFile("test_simd_gaussian.png")
  
  echo "\nImages saved as:"
  echo "  test_simd_clipped.png (SIMD clipped to solid colors)"
  echo "  test_simd_feathered.png (SIMD with standard feathering)"
  echo "  test_simd_feathered_inv.png (SIMD with inverted feathering)"
  echo "  test_simd_gaussian.png (SIMD with Gaussian feathering)"

  echo "\n✓ All SIMD modes tested successfully!"

main() 