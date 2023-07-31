
import std/asyncdispatch
import times, std/monotimes, strutils # This is to provide the timing output

export asyncdispatch

type
  FrameIdx* = tuple[count: int, skipped: int]

proc runEveryMillis*(ms: int, repeat: int, code: proc (idx: FrameIdx): bool) {.async.} =
  var
    start = getMonoTime()
    idx = 0
    prev = 0

  while idx < repeat:
    var curr = getMonoTime()
    prev = idx
    idx.inc()
    var next = start + initDuration(milliseconds= idx * ms) 
    while next < curr:
      next = start + initDuration(milliseconds= idx * ms) 
      idx.inc()
    # if idx - prev > 1:
    #   echo "frame skip: ", (idx-prev-1), " next: ", inMilliseconds(next-start), " vs ", inMilliseconds(curr-start)
    await sleepAsync(inMilliseconds(next - curr).int)
    let done = code((count: idx, skipped: idx - prev - 1))
    if done:
      break

proc runForMillis*(ms: int, code: proc (idx: FrameIdx): bool) {.async.} =
  let frameDelayMs = 32
  await runEveryMillis(frameDelayMs, repeat=ms div frameDelayMs, code)
