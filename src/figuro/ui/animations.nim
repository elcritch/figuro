import std/[monotimes, times]
import pkg/sigils
import pkg/chronicles
import ../commons
import apis

type FadeAnimation* = object
  minMax*: Slice[float]
  incr*: float
  decr*: float
  active*: bool = false
  amount*: float = 0.0

proc tick*(self: var FadeAnimation, node: Figuro): bool {.discardable.} =
  if self.active and self.amount < self.minMax.b:
    self.amount += self.incr
    refresh(node)
    result = true
  elif not self.active and self.amount > self.minMax.a:
    self.amount -= self.decr
    refresh(node)
    result = true

proc isActive*(self: var FadeAnimation, isActive = true) =
  self.active = isActive

proc setMax*(self: var FadeAnimation) =
  self.amount = self.minMax.b

proc setMin*(self: var FadeAnimation) =
  self.amount = self.minMax.a


type Fader* = ref object of Agent
  active*: bool = false
  fadingIn*: bool = false
  amount*: float = 0.0
  minMax*: Slice[float] = 0.0..1.0
  ts*: MonoTime
  fadeIn*: Duration
  fadeOut*: Duration
  ratePerMs: Slice[float]
  node: Figuro

proc tick*(self: Fader, now: MonoTime, delta: Duration) {.slot.} =
  echo "fader tick: ", delta
  discard

proc start*(self: Fader, node: Figuro, fadeIn: bool) {.slot.} =
  self.active = true
  self.ts = getMonoTime()
  self.fadingIn = fadeIn
  let delta = self.minMax.b - self.minMax.a
  if self.fadeIn.inMilliseconds > 0:
    self.ratePerMs.a = delta / self.fadeIn.inMilliseconds.toFloat
  if self.fadeOut.inMilliseconds > 0:
    self.ratePerMs.b = delta / self.fadeOut.inMilliseconds.toFloat
  connect(node.frame[].root, doTick, self, tick)
  info "self: started: ", ratePerMs= self.ratePerMs, fadeOn= self.fadeIn, fadeOut= self.fadeOut

proc stop*(self: Fader) {.slot.} =
  self.active = true

proc fadeIn*(self: Fader, node: Figuro) {.slot.} =
  self.start(node, true)

proc fadeOut*(self: Fader, node: Figuro) {.slot.} =
  self.start(node, false)

proc setMax*(self: Fader) {.slot.} =
  self.amount = self.minMax.b

proc setMin*(self: Fader) {.slot.} =
  self.amount = self.minMax.a
