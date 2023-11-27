
import apis

type
  FadeAnimation* = object
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
