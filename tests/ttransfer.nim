
import std/unittest
import figuro/widget
import figuro/common/nodes/render
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
    let res1 = renders[0.ZLevel].childIndex(0.NodeIdx)
    print res1.mapIt(it+1)
    let res2 = renders[0.ZLevel].childIndex(1.NodeIdx)
    print res2.mapIt(it+1)
