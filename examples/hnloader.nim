import sigils
import std/httpclient
import std/os
import std/sequtils
import std/strutils

import chame/minidom
import pretty

type HtmlLoader* = ref object of Agent
  url: string

proc parseTable(mainTable: Element) =
  echo "main table: ", mainTable.localNameStr()
  echo "main: ", mainTable.attrsStr().toSeq()
  echo ""

  var stack: seq[Node] = mainTable.childList
  block outer:
    while stack.len > 0:
      let node = stack.pop()
      if node of Text:
        let s = Text(node)
        # echo "text: ", s.data.strip()
      elif node of Element:
        let elem = Element(node)
        if elem.localNameStr == "table":
          echo "element: ", elem.localNameStr()
          echo "element: ", elem.attrsStr().toSeq()
      for i in countdown(node.childList.high, 0):
        stack.add(node.childList[i])

proc loadPage(loader: HtmlLoader) {.slot.} =
  echo "Starting page load..."
  let client = newHttpClient()
  let res = client.get(loader.url)
  let document = parseHTML(res.bodyStream)
  var stack = @[Node(document)]

  block outer:
    while stack.len > 0:
      let node = stack.pop()
      if node of Text:
        let s = Text(node)
        # echo "text: ", s.data.strip()
      elif node of Element:
        let elem = Element(node)
        if elem.localNameStr == "table":
          echo "element: ", elem.localNameStr()
          # echo "element: ", elem.attrsStr().toSeq()
          for name, value in elem.attrsStr():
            if name == "id":
              echo "element: found table "
              parseTable(elem)
              break outer
      for i in countdown(node.childList.high, 0):
        stack.add(node.childList[i])

when isMainModule:
  let l = HtmlLoader(url: "https://news.ycombinator.com")
  l.loadPage()
