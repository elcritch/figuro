
import std/unittest
import figuro/widget
import figuro/common/nodes/transfer

import pretty

suite "test layers":

  suite "basic single layer":
    var self = Figuro.new()
    echo "self: ", self.agentId
    echo "self: ", self.uid
    withDraw(self):
      rectangle "body":
        rectangle "child1":
          discard
        rectangle "child2":
          discard
        rectangle "child3":
          discard

    let renders = copyInto(self)
    print renders
    # childIndex()