
import std/unittest
import figuro/widget
import figuro/common/nodes/ui
import figuro/common/nodes/render
import figuro/common/nodes/transfer

import pretty

suite "test layers":

  suite "basic single layer":
    var self = Figuro.new()
    withDraw(self):
      rectangle "body":
        rectangle "child1":
          discard
        rectangle "child2":
          discard
        rectangle "child3":
          discard
      rectangle "body":
        discard

    emit self.doDraw()

    let renders = copyInto(self)
    # for k, v in renders.pairs():
    #   print k
    #   for n in v:
    #     print "node: ", "uid:", n.uid, "child:", n.childCount, "parent:", n.parent
    let n1 = renders[0.ZLevel].childIndex(0.NodeIdx)
    let res1: seq[int] = n1.mapIt(it+1)
    check res1.repr == "@[2, 6]"

    let n2 = renders[0.ZLevel].childIndex(1.NodeIdx)
    let res2 = n2.mapIt(it+1)
    check res2.repr == "@[3, 4, 5]"

  suite "basic two layer":
    var self = Figuro.new()
    echo "self: ", self.agentId
    echo "self: ", self.uid
    withDraw(self):
      rectangle "body":
        rectangle "child1":
          current.zlevel = 11
        rectangle "child2":
          discard
        rectangle "child3":
          discard
      rectangle "body":
        current.zlevel = 12
        rectangle "child4":
          discard

    emit self.doDraw()

    let renders = copyInto(self)
    for k, v in renders.pairs():
      print k
      for n in v:
        print "node: ", "uid:", n.uid, "child:", n.childCount, "parent:", n.parent, "zlevel:", n.zlevel
    let n1 = renders[0.ZLevel].childIndex(0.NodeIdx)
    let res1: seq[int] = n1.mapIt(it+1)
    check res1.repr == "@[2, 6]"

    let n2 = renders[0.ZLevel].childIndex(1.NodeIdx)
    let res2 = n2.mapIt(it+1)
    print res2
    check res2.repr == "@[3, 4, 5]"

