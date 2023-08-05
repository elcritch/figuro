
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

proc eventActions*() =
  when defined(inputDownEventExample):
    let
      setKey = action != 0
      button = button + 1 # Fidget mouse buttons are +1 from windy
    if button < window.buttonDown.len:
      if buttonDown[button] == false and setKey == true:
        buttonPress[button] = true
      buttonDown[button] = setKey

  when defined(inputReleaseEventExample):
    if buttonDown[button] == false and setKey == false:
      buttonRelease[button] = true