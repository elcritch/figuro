
import std/unittest
import std/strutils
import figuro/widget
import figuro/common/nodes/ui
import figuro/common/nodes/render
import figuro/common/nodes/transfer

import pretty

suite "test layers":

  # suite "basic single layer":
  #   var self = Figuro.new()
  #   withDraw(self):
  #     rectangle "body":
  #       rectangle "child1":
  #         discard
  #       rectangle "child2":
  #         discard
  #       rectangle "child3":
  #         discard
  #     rectangle "body":
  #       discard

  #   emit self.doDraw()

  #   let renders = copyInto(self)
  #   # for k, v in renders.pairs():
  #   #   print k
  #   #   for n in v:
  #   #     print "node: ", "uid:", n.uid, "child:", n.childCount, "parent:", n.parent
  #   let n1 = renders[0.ZLevel].childIndex(0.NodeIdx)
  #   let res1 = n1.mapIt(it+1.NodeIdx)
  #   check res1.repr == "@[2, 6]"

  #   let n2 = renders[0.ZLevel].childIndex(1.NodeIdx)
  #   let res2 = n2.mapIt(it+1.NodeIdx)
  #   check res2.repr == "@[3, 4, 5]"

  # suite "basic two layer":
  #   var self = Figuro.new()
  #   echo "self: ", self.agentId
  #   echo "self: ", self.uid
  #   withDraw(self):
  #     rectangle "body":
  #       rectangle "child0":
  #         discard
  #         rectangle "child01":
  #           discard
  #       rectangle "child1":
  #         current.zlevel = 11
  #       rectangle "child2":
  #         discard
  #       rectangle "child3":
  #         discard
  #     rectangle "body":
  #       current.zlevel = 12
  #       rectangle "child4":
  #         discard

  #   emit self.doDraw()

  #   proc printUiNodes(n: Figuro) =
  #     print "\tuiNode: ", "uid:", n.uid, "pnt:", n.parent.getId, "zlvl:", n.zlevel
  #     for c in n.children:
  #       printUiNodes(c)

  #   print "\nuinodes:"
  #   printUiNodes(self)

  #   let renders = copyInto(self)
  #   for k, v in renders.pairs():
  #     print k
  #     for n in v:
  #       print "\tnode: ", "uid:", n.uid, "child:", n.childCount, "chCnt:", n.childCount, "pnt:", n.parent, "zlvl:", n.zlevel
  #   let n1 = renders[0.ZLevel].childIndex(0.NodeIdx)
  #   let uids1 = n1.mapIt(renders[0.ZLevel][it.int].uid)
  #   print uids1
  #   check uids1.repr == "@[8]"

  #   let n2 = renders[0.ZLevel].childIndex(1.NodeIdx)
  #   # let res2 = n2.mapIt(it)
  #   let uids2 = n2.mapIt(renders[0.ZLevel][it.int].uid)
  #   print uids2
  #   check uids2.repr == "@[9, 12, 13]"

  #   proc printRenders(nodes: seq[Node], idx: NodeIdx, depth = 0) =
  #     let n = nodes[idx.int]
  #     print "  ".repeat(depth), "render: ", n.uid, " p: ", n.parent
  #     let childs = nodes.childIndex(idx)
  #     for ci in childs:
  #       printRenders(nodes, ci, depth+1)

  #   printRenders(renders[0.ZLevel], 0.NodeIdx)
  #   printRenders(renders[11.ZLevel], 0.NodeIdx)
  #   printRenders(renders[12.ZLevel], 0.NodeIdx)

  suite "three layer out of order":
    var self = Figuro.new()
    echo "self: ", self.agentId
    echo "self: ", self.uid
    withDraw(self):
      current.zlevel = 20
      rectangle "body":
        rectangle "child0":
          discard
          rectangle "child01":
            discard
      rectangle "child1":
        current.zlevel = 30
        rectangle "child11":
          discard
        rectangle "child12":
          discard
        rectangle "child13":
          current.zlevel = -10
          rectangle "child131":
            discard

    emit self.doDraw()

    let renders = copyInto(self)

    echo "\n"
    for k, v in renders.pairs():
      print k
      for n in v:
        print "   node: ",
          "uid:", n.uid,
          " // ", n.parent,
          "chCnt:", n.childCount,
          "zlvl:", n.zlevel,
          "n:", $n.name

    assert -10.ZLevel in renders
    check renders[-10.ZLevel].len() == 2
    check renders[20.ZLevel].len() == 4
    check renders[30.ZLevel].len() == 3

    printRenders(renders[20.ZLevel], 0.NodeIdx)
    printRenders(renders[30.ZLevel], 0.NodeIdx)
    # printRenders(renders[10.ZLevel], 0.NodeIdx)

    # check uids1.repr == "@[8]"
    

