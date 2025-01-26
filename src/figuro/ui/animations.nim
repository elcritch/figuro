import std/[monotimes, times]
import pkg/sigils
import pkg/chronicles
import ../commons
import apis

type Fader* = ref object of Agent
  minMax*: Slice[float] = 0.0..1.0
  inTimeMs*: int
  outTimeMs*: int
  fadingIn: bool = false
  active: bool = false
  amount: float = 0.0
  ts: MonoTime
  ratePerMs: Slice[float]
  targets: seq[Figuro]

proc amount*(fader: Fader): float = fader.amount
proc fadeTick*(fader: Fader, value: tuple[amount, perc: float], finished: bool) {.signal.}

proc addTarget*(self: Fader, node: Figuro) {.slot.} =
  when (NimMajor, NimMinor, NimPatch) < (2, 2, 0):
    if node notin self.targets:
      self.targets.add(node)
  else:
    self.targets.addUnique(node)

proc tick*(self: Fader, now: MonoTime, delta: Duration) {.slot.} =
  let rate = if self.fadingIn: self.ratePerMs.a else: self.ratePerMs.b
  let dt = delta.inMilliseconds.toFloat
  if self.fadingIn:
    self.amount = self.amount + rate * dt
    if self.amount >= self.minMax.b:
      self.amount = self.minMax.b
      self.active = false
  elif not self.fadingIn:
    self.amount = self.amount - rate * dt
    if self.amount <= self.minMax.a:
      self.amount = self.minMax.a
      self.active = false
  # trace "fader:tick: ", amount = self.amount
  
  let (x,y) = if self.fadingIn: (self.minMax.b, self.minMax.a)
              else: (self.minMax.a, self.minMax.b)

  let val = (amount: self.amount, perc: (self.amount-x)/(y-x))
  if self.active:
    emit self.fadeTick(val, false)
  else:
    for tgt in self.targets:
      disconnect(tgt.frame[].root, doTick, self)
    emit self.fadeTick(val, true)

proc stop*(self: Fader) {.slot.} =
  self.active = false
  for tgt in self.targets:
    disconnect(tgt.frame[].root, doTick, self)

proc startFade*(self: Fader, fadeIn: bool) {.slot.} =
  self.active = true
  self.ts = getMonoTime()
  self.fadingIn = fadeIn
  let delta = self.minMax.b - self.minMax.a
  if self.inTimeMs > 0:
    self.ratePerMs.a = delta / self.inTimeMs.toFloat
  if self.outTimeMs > 0:
    self.ratePerMs.b = delta / self.outTimeMs.toFloat
  for tgt in self.targets:
    connect(tgt.frame[].root, doTick, self, tick)
  # trace "fader:started: ", amt = self.amount, ratePerMs= self.ratePerMs, fadeOn= self.inTimeMs, fadeOut= self.outTimeMs

proc fadeIn*(self: Fader) {.slot.} =
  self.startFade(true)

proc fadeOut*(self: Fader) {.slot.} =
  self.startFade(false)

proc setMax*(self: Fader) {.slot.} =
  self.amount = self.minMax.b

proc setMin*(self: Fader) {.slot.} =
  self.amount = self.minMax.a
