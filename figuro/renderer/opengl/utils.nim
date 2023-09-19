
import pkg/opengl
import pkg/windy

proc openglDebug*() =
  when defined(glDebugMessageCallback):
    let flags = glGetInteger(GL_CONTEXT_FLAGS)
    if (flags and GL_CONTEXT_FLAG_DEBUG_BIT.GLint) != 0:
      # Set up error logging
      proc printGlDebug(
        source, typ: GLenum,
        id: GLuint,
        severity: GLenum,
        length: GLsizei,
        message: ptr GLchar,
        userParam: pointer
      ) {.stdcall.} =
        echo &"source={toHex(source.uint32)} type={toHex(typ.uint32)} " &
          &"id={id} severity={toHex(severity.uint32)}: {$message}"
        if severity != GL_DEBUG_SEVERITY_NOTIFICATION:
          running = false
      glDebugMessageCallback(printGlDebug, nil)
      glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS)
      glEnable(GL_DEBUG_OUTPUT)

  when defined(printGLVersion):
    echo getVersionString()
    echo "GL_VERSION:", cast[cstring](glGetString(GL_VERSION))
    echo "GL_SHADING_LANGUAGE_VERSION:",
      cast[cstring](glGetString(GL_SHADING_LANGUAGE_VERSION))

proc setOpenGlHints*() =
  # these don't work in windy?
  when defined(setOpenGlHintsEnabled):
    if msaa != msaaDisabled:
      windowHint(SAMPLES, msaa.cint)
    windowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
    windowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
    windowHint(CONTEXT_VERSION_MAJOR, openglVersion[0].cint)
    windowHint(CONTEXT_VERSION_MINOR, openglVersion[1].cint)
