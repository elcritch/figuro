switch("styleCheck", "hint")

--path:"$nim" ## important for nimscripter

# --gc:orc
--gc:arc
--d:useMalloc

--d:windyNoHttp
--d:printDebugTimings
# --d:nimStrictDelete
--deepcopy:on
--debugger:native
--debugInfo
--define:"chronicles_log_level:DEBUG"
# --define:"chronicles_log_level:TRACE"

--hint:"ConvFromXtoItselfNotNeeded:off"

if not defined(emscripten):
  --threads:on

--define:"chronicles_sinks:textlines"
--define:"chronicles_indent:2"
--define:"chronicles_timestamps:NoTimestamps"

import os

if defined(emscripten):
  # This path will only run if -d:emscripten is passed to nim.

  --nimcache:tmp # Store intermediate files close by in the ./tmp dir.

  --os:linux # Emscripten pretends to be linux.
  --cpu:i386 # Emscripten is 32bits.
  --cc:clang # Emscripten is very close to clang, so we ill replace it.
  --clang.exe:emcc.bat  # Replace C
  --clang.linkerexe:emcc.bat # Replace C linker
  --clang.cpp.exe:emcc.bat # Replace C++
  --clang.cpp.linkerexe:emcc.bat # Replace C++ linker.
  --listCmd # List what commands we are running so that we can debug them.

  --gc:arc # GC:arc is friendlier with crazy platforms.
  --exceptions:goto # Goto exceptions are friendlier with crazy platforms.

  --d:noSignalHandler

  # Pass this to Emscripten linker to generate html file scaffold for us.
  # switch("passL", "-o wasm.html")
  # #switch("--preload-file data")
  # switch("--shell-file src/shell_minimal.html")

elif defined(macosx):
  # --d:pixieNoSimd
  --d:kqueueUserEvent
  --threads:on
  when gorge("brew --prefix fswatch").dirExists():
    --define:figuroFsMonitor
    --passL:"-Wl,-rpath,/opt/homebrew/opt/fswatch/lib"
    --passL:"-Wl,-rpath,/usr/local/homebrew/opt/fswatch/lib"

import std/os
import std/strutils

task test, "compile tests":
  # unit tests
  for (k, f) in walkDir("tests/unittests/"):
    if k != pcDir and f.startsWith("t") and f.endsWith(".nim"):
      # echo "F: ", f
      exec "nim c -r " & f
  
  # test compile widgets
  for (k, f) in walkDir("tests"):
    if k != pcDir and f.startsWith("t") and f.endsWith(".nim"):
      # echo "F: ", f
      exec "nim c " & f
