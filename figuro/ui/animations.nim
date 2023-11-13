
import apis

type
  FadeAnimation* = object
    minMax*: Slice[float]
    incr*: float
    decr*: float
    active*: bool = false
    alpha*: float = 0.0

proc tick*(self: var FadeAnimation, node: Figuro): bool =
  if self.active and self.alpha < self.minMax.b:
    self.alpha += self.incr
    refresh(node)
    result = true
  elif not self.active and self.alpha > self.minMax.a:
    self.alpha -= self.decr
    refresh(node)
    result = true

proc isActive*(self: var FadeAnimation, isActive = true) =
  self.active = isActive
