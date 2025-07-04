version       = "0.16.1"
author        = "Jaremy Creechley"
description   = "UI Engine for Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.10"
requires "cssgrid >= 0.13.6"
requires "sigils >= 0.11.10"
requires "pixie >= 5.0.1"
requires "chroma >= 0.2.7"
requires "bumpy"
requires "pretty"
requires "stew == 0.2.0"
requires "chronicles >= 0.10.3"
requires "https://github.com/elcritch/sdfy >= 0.7.7"
requires "supersnappy >= 2.1.3"
requires "variant >= 0.2.12"
requires "opengl >= 1.2.6"
requires "zippy >= 0.10.4"
requires "patty >= 0.3.4"
requires "macroutils >= 1.2.0"
requires "cdecl >= 0.7.5"
requires "asynctools >= 0.1.1"
requires "nimsimd >= 1.2.5"
requires "threading >= 0.2.1"
requires "stack_strings"
requires "micros"
requires "stylus >= 0.1.3"
requires "https://github.com/elcritch/windex >= 0.1.4"
requires "dmon >= 0.4.0"
requires "htmlparser"

feature "siwin":
  requires "siwin"

feature "boxy":
  requires "boxy"

feature "nimvm":
  requires "nimscripter >= 1.1.5"
  requires "msgpack4nim"

feature "thorvg":
  requires "https://github.com/thorvg/thorvg#head"

