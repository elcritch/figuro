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
  amount*: float = 0.0
  minMax*: Slice[float] = 0.0..1.0
  on*: Duration
  off*: Duration
  node*: Figuro

proc tick*(self: Fader, now: MonoTime, delta: Duration) {.slot.} =
  echo "fader tick: ", delta
  discard

proc start*(self: Fader, node: Figuro) {.slot.} =
  self.active = true
  connect(node.frame[].root, doTick, self, tick)

proc stop*(self: Fader) {.slot.} =
  self.active = true

proc setMax*(self: Fader) {.slot.} =
  self.amount = self.minMax.b

proc setMin*(self: Fader) {.slot.} =
  self.amount = self.minMax.a
