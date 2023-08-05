import std/[os, hashes, strformat, strutils, tables, times]

import pkg/chroma
import pkg/[typography, typography/svgfont]
import pkg/pixie

import opengl/[base, context, draw]
import ../[common, internal]

when not defined(emscripten) and not defined(fidgetNoAsync):
  import httpClient, asyncdispatch, asyncfutures, json

export draw

var
  windowTitle, windowUrl: string

proc drawFrame*() =
  # echo "\ndrawFrame"
  clearColorBuffer(color(1.0, 1.0, 1.0, 1.0))
  ctx.beginFrame(windowSize)
  ctx.saveTransform()
  ctx.scale(ctx.pixelScale)

  mouse.cursorStyle = Default

  # Only draw the root after everything was done:
  drawRoot(renderRoot)

  ctx.restoreTransform()
  ctx.endFrame()

  # Only set mouse style when it changes.
  if mouse.prevCursorStyle != mouse.cursorStyle:
    mouse.prevCursorStyle = mouse.cursorStyle
    echo mouse.cursorStyle
    case mouse.cursorStyle:
      of Default:
        setCursor(cursorDefault)
      of Pointer:
        setCursor(cursorPointer)
      of Grab:
        setCursor(cursorGrab)
      of NSResize:
        setCursor(cursorNSResize)

  when defined(testOneFrame):
    ## This is used for test only
    ## Take a screen shot of the first frame and exit.
    var img = takeScreenshot()
    img.writeFile("screenshot.png")
    quit()

const
  openglMajor {.intdefine.} = 3
  openglMinor {.intdefine.} = 3

proc setupWindow*(
    pixelate: bool,
    forcePixelScale: float32,
    atlasSize: int = 1024
) =

  let openglVersion = (openglMajor, openglMinor)
  pixelScale = forcePixelScale

  base.start(openglVersion)

  setWindowTitle(windowTitle)
  ctx = newContext(atlasSize = atlasSize, pixelate = pixelate, pixelScale = pixelScale)
  requestedFrame.inc

  base.drawFrame = drawFrame

  useDepthBuffer(false)

  if loadMain != nil:
    loadMain()

