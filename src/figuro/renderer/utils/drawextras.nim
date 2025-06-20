# import glcommons
import std/hashes

import ../../commons
import ../../common/nodes/render

import pkg/chroma
import pkg/sigils
import pkg/chronicles
import pkg/pixie

import ./drawutils

proc sliceToNinePatch*(img: Image): tuple[
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
  
  # echo "sliceToNinePatch: ", width, "x", height, " halfW: ", halfW, " halfH: ", halfH

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
