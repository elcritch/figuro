import std/[times, math, monotimes, strutils, macros] # This is to provide the timing output
import pkg/chronicles

type
  FrameIdx* = tuple[count: int, skipped: int]
  TimeIt* = tuple[micros: float, count: int]

proc logTiming(name, time: string) =
  info "timings", name = name, time = time

const
  timeItSmoothing {.intdefine.} = 10
  alpha = 1.0 / timeItSmoothing.toFloat
  printEvery = 1_00

proc toMillis*(t: TimeIt): float =
  round(t.micros / 1_000.0, 3)

macro timeIt*(timer, blk: untyped) =
  let name = newStrLitNode timer.repr()
  if defined(printDebugTimings):
    let timer = ident($name)
    result = quote do:
      var `timer` {.global, inject, threadvar.}: TimeIt
      let a = getMonoTime()
      `blk`
      let b = getMonoTime()
      let res = b - a
      let micros = res.inMicroseconds.toFloat
      `timer`.micros =  alpha * micros + (1.0-alpha) * `timer`.micros
      `timer`.count.inc
      if `timer`.count mod printEvery == 0:
        let num = toMillis(`timer`)
        logTiming($`name`, $num.formatBiggestFloat(ffDecimal, 3) & " ms")
  else:
    result = quote do:
      `blk`

proc runEveryMillis*(ms: int, repeat: int, code: proc(idx: FrameIdx): bool) =
  when false:
    var
      start = getMonoTime()
      idx = 0
      prev = 0

    while idx < repeat:
      var curr = getMonoTime()
      prev = idx
      idx.inc()
      var next = start + initDuration(milliseconds = idx * ms)
      while next < curr:
        next = start + initDuration(milliseconds = idx * ms)
        idx.inc()
      # if idx - prev > 1:
      #   echo "frame skip: ", (idx-prev-1), " next: ", inMilliseconds(next-start), " vs ", inMilliseconds(curr-start)
      # await sleepAsync(inMilliseconds(next - curr).int)
      let done = code((count: idx, skipped: idx - prev - 1))
      if done:
        break

proc runForMillis*(ms: int, code: proc(idx: FrameIdx): bool) =
  when false:
    let frameDelayMs = 32
    await runEveryMillis(frameDelayMs, repeat = ms div frameDelayMs, code)
