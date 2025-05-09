import std/[sets, monotimes, times]
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
  targets: OrderedSet[Figuro]

proc amount*(fader: Fader): float = fader.amount
proc doFadeTick*(fader: Fader, value: tuple[amount, perc: float], finished: bool) {.signal.}

proc active*(self: Fader): bool =
  self.active

proc addTarget*(self: Fader, node: Figuro, noRefresh = false) =
  self.targets.incl(node)
  if not noRefresh:
    connect(self, doFadeTick, node, Figuro.refresh(), true)

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
  debug "fader:tick: ", self = $self.unsafeWeakRef, amount = self.amount, rate = rate, dt = dt, minMax = self.minMax
  
  let (x,y) = if self.fadingIn: (self.minMax.b, self.minMax.a)
              else: (self.minMax.a, self.minMax.b)

  let val = (amount: self.amount, perc: (self.amount-x)/(y-x))
  if self.active:
    debug "fader:tick:send: ", self = $self.unsafeWeakRef, amount = self.amount, rate = rate, dt = dt, minMax = self.minMax
    emit self.doFadeTick(val, false)
  else:
    debug "fader:stop: ", self = $self.unsafeWeakRef
    for tgt in self.targets:
      disconnect(tgt.frame[].root, doTick, self)
      break
    emit self.doFadeTick(val, true)

proc startFade*(self: Fader, fadeIn: bool) {.slot.} =
  # echo "fade:startFade: ", fadeIn
  self.active = true
  self.ts = getMonoTime()
  self.fadingIn = fadeIn
  let delta = self.minMax.b - self.minMax.a
  if self.inTimeMs > 0:
    self.ratePerMs.a = delta / self.inTimeMs.toFloat
  if self.outTimeMs > 0:
    self.ratePerMs.b = delta / self.outTimeMs.toFloat
  for tgt in self.targets:
    # echo "fader:start:connect:root: ", tgt.frame[].root.name
    connect(tgt.frame[].root, doTick, self, tick)
    break
  debug "fader:started: ", self = $self.unsafeWeakRef, amt = self.amount, ratePerMs= self.ratePerMs, fadeOn= self.inTimeMs, fadeOut= self.outTimeMs

proc stop*(self: Fader) {.slot.} =
  self.active = false
  for tgt in self.targets:
    disconnect(tgt.frame[].root, doTick, self)

proc fadeIn*(self: Fader) {.slot.} =
  self.startFade(true)

proc fadeOut*(self: Fader) {.slot.} =
  self.startFade(false)

proc setValue*(self: Fader, value: float) {.slot.} =
  self.amount = value

proc resets*(self: Fader) {.slot.} =
  self.active = false
  self.amount = self.minMax.a
  for tgt in self.targets:
    disconnect(tgt.frame[].root, doTick, self)
    break
  let val = (amount: self.amount, perc: 0.0)
  emit self.doFadeTick(val, true)

proc setMax*(self: Fader) {.slot.} =
  self.amount = self.minMax.b

proc setMin*(self: Fader) {.slot.} =
  self.amount = self.minMax.a
