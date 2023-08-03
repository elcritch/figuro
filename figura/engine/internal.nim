
type
  MainCallback* = proc() {.nimcall.}

var
  drawMain*: MainCallback
  tickMain*: MainCallback
  loadMain*: MainCallback
