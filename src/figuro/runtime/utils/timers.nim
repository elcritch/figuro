import std/[times, monotimes, strutils, macros] # This is to provide the timing output
import pkg/chronicles

type
  FrameIdx* = tuple[count: int, skipped: int]
  TimeIt* = tuple[micros: float, count: int]

proc logTiming(name, time: string) =
  info "timings", name = name, time = time

proc timeItImpl*(retVar: bool, timer, blk: NimNode): NimNode =
  let name = newStrLitNode timer.repr()
  if defined(printDebugTimings):
    let timer = genSym(nskVar, "timer")
    result = quote do:
      var `timer` {.global, threadvar.}: TimeIt
      let a = getMonoTime()
      `blk`
      let b = getMonoTime()
      let res = b - a
      let micros = res.inMicroseconds
      `timer`.micros = 0.99 * `timer`.micros + 0.01 * micros.toBiggestFloat
      `timer`.count.inc
      if `timer`.count mod 1_000 == 0:
        let num = `timer`.micros / 1_000.0
        logTiming($`name`, $num.formatBiggestFloat(ffDecimal, 3) & " ms")
    if retVar:
      result.add quote do:
        `timer`
  else:
    result = quote do:
      `blk`

macro timeIt*(timer, blk: untyped) =
  result = timeItImpl(false, timer, blk)
macro timeItVar*(timer, blk: untyped): TimeIt =
  result = timeItImpl(true, timer, blk)

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
