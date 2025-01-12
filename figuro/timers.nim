import std/[times, monotimes, strutils, macros] # This is to provide the timing output

type
  FrameIdx* = tuple[count: int, skipped: int]
  TimeIt* = tuple[micros: float, count: int]

macro timeIt*(timer, blk: untyped) =
  let name = newStrLitNode timer.repr()
  if defined(printDebugTimings):
    quote:
      var timer {.global, threadvar.}: TimeIt
      let a = getMonoTime()
      `blk`
      let b = getMonoTime()
      let res = b - a
      let micros = res.inMicroseconds
      timer.micros = 0.99 * timer.micros + 0.01 * micros.toBiggestFloat
      timer.count.inc
      if timer.count mod 1_000 == 0:
        let num = timer.micros / 1_000.0
        echo "timing:", `name`, ": ", num.formatBiggestFloat(ffDecimal, 3), " ms"
  else:
    quote:
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
