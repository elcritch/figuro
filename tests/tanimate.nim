## This minimal example shows 5 blue squares.

import figura/timers
import figura/engine

type
  Item = ref object
    value: float

proc ticker(self: Item) {.async.} =
  ## This simple procedure will "tick" ten times delayed 1,000ms each.
  ## Every tick will increment the progress bar 10% until its done. 
  let duration = 3_000

  await runForMillis(duration) do (frame: FrameIdx) -> bool:
    refresh()
    self.value += 0.05 * (1+frame.skipped).toFloat
    self.value = clamp(self.value mod 1.0, 0, 1.0)

var
  ticks: Future[void] = emptyFuture() ## Create an completed "empty" future
  item = Item()

proc drawMain() =
  if ticks.finished:
    ticks = ticker(item)
  
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      group "block":
        box 20 + (i.toFloat + item.value) * 120, 20, 100, 100
        fill "#2B9FEA"

startFidget(drawMain, w = 620, h = 140)
