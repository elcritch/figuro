
import std/unittest
import std/strutils
import pkg/sigils
import pkg/chronicles
import pkg/pretty
import pkg/pretty

import figuro/ui/layout
import figuro/widget
import figuro/common/nodes/uinodes
import figuro/common/nodes/render
import figuro/common/nodes/transfer

type
  TestBasic = ref object of Figuro
  TestFig = ref object of Figuro

proc draw(fig: TestBasic) {.slot.} =
  withWidget(fig):
    Rectangle.new "body":
      echo "body"
      Rectangle.new "child1":
        echo "child1"
        discard
      Rectangle.new "child2":
        discard
      Rectangle.new "child3":
        discard
    Rectangle.new "body2":
      discard

proc draw(fig: TestFig) {.slot.} =
  withWidget(fig):
    this.zlevel = 20
    # discard this.name.tryAdd("root")
    this.name = atom"root"
    Rectangle.new "body":
      Rectangle.new "child0":
        discard
        Rectangle.new "child01":
          discard
    Rectangle.new "child1":
      this.zlevel = 30
      Rectangle.new "child11":
        discard
      Rectangle.new "child12":
        discard
      Rectangle.new "child13":
        this.zlevel = -10
        Rectangle.new "child131":
          discard
    Rectangle.new "body2":
      Rectangle.new "child21":
        this.zlevel = -10


suite "test layers":

  test "basic single layer":
    var self = TestBasic()
    var frame = newAppFrame[TestBasic](root=self, size=(100'ui, 100'ui))
    var node = self

    printConnections(self)
    emit self.doDraw()

    let renders = copyInto(self)
    # for k, v in renders.pairs():
    #   print k
    #   for n in v:
    #     print "node: ", "uid:", n.uid, "child:", n.childCount, "parent:", n.parent
    let n1 = renders[0.ZLevel].toTree()
    # print n1
    let n2 = renders[0.ZLevel]
    # print n2.rootIds
    check n2.rootIds.len() == 1
    check n2.rootIds[0] == NodeIdx 0

    # let res2 = n2.mapIt(it+1.NodeIdx)
    # check res2.repr == "@[3, 4, 5]"

  # suite "basic two layer":
  #   var self = Figuro.new()
  #   echo "self: ", self.agentId
  #   echo "self: ", self.uid
  #   nodes(self):
  #     rectangle "body":
  #       rectangle "child0":
  #         discard
  #         rectangle "child01":
  #           discard
  #       rectangle "child1":
  #         this.zlevel = 11
  #       rectangle "child2":
  #         discard
  #       rectangle "child3":
  #         discard
  #     rectangle "body":
  #       this.zlevel = 12
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

  test "three layer out of order":

    var node = TestFig()
    var frame = newAppFrame(root=node, size=(100'ui, 100'ui))

    printConnections(node)
    echo "node: ", node.contents
    emit node.doDraw()
    printLayout(node)

    let renders = copyInto(node)

    echo "\n"
    for k, v in renders.pairs():
      echo k, v.rootIds
      for n in v.nodes:
        echo "   node: ",
          " uid:", n.uid,
          " // ", n.parent,
          " chCnt:", n.childCount,
          " zlvl:", n.zlevel,
          " n:", $n.name

    assert -10.ZLevel in renders
    check renders[-10.ZLevel].nodes.len() == 3
    check renders[20.ZLevel].nodes.len() == 5
    check renders[30.ZLevel].nodes.len() == 3

    echo "\nzlevel: ", -10.ZLevel
    echo repr renders[-10.ZLevel].toTree()
    let res10 = renders[-10.ZLevel].toTree()
    check res10.name == "pseudoRoot"
    check res10[0].name == "child13"
    check res10[0][0].name == "child131"
    check res10[1].name == "child21"

    echo "\nzlevel: ", 20.ZLevel
    let res20 = renders[20.ZLevel].toTree()
    echo "res20: ", res20.repr

    check res20.name == "pseudoRoot"
    check res20.children.len() == 1
    check res20[0].children.len() == 2
    check res20[0][0].children.len() == 1
    check res20[0][0][0].children.len() == 1

    check res20[0].name == "root"
    check res20[0][0].name == "body"
    check res20[0][0][0].name == "child0"
    check res20[0][0][0][0].name == "child01"
    check res20[0][1].name == "body2"

    echo "\nzlevel: ", 30.ZLevel
    let res30 = renders[30.ZLevel].toTree()
    echo "res30: ", res30.repr

    check res30.name == "pseudoRoot"
    check res30.children.len() == 1
    check res30[0].children.len() == 2
    check res30[0].name == "child1"
    check res30[0][0].name == "child11"
    check res30[0][1].name == "child12"


    # printRenders(renders[30.ZLevel], 0.NodeIdx)
    # printRenders(renders[-10.ZLevel], 0.NodeIdx)

    # print -10.Zlevel, lispRepr(renders[-10.ZLevel])
    # print 20.Zlevel, lispRepr(renders[20.ZLevel])
    # print 30.Zlevel, lispRepr(renders[30.ZLevel])
    # # check uids1.repr == "@[8]"


