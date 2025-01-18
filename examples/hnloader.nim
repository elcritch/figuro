import sigils
import std/httpclient
import std/os
import std/sequtils
import std/strutils

# import chame/minidom
import std/htmlparser
import std/xmltree
import std/strtabs

import pretty

type HtmlLoader* = ref object of Agent
  url: string

proc parseTable(mainTable: XmlNode) =
  # echo "main table: ", mainTable.localNameStr()
  discard

iterator elems*(n: XmlNode): XmlNode {.inline.} =
  for c in n:
    if c.kind == xnElement:
      yield c

proc loadPage(loader: HtmlLoader) {.slot.} =
  echo "Starting page load..."
  let client = newHttpClient()
  # let res = client.get(loader.url)
  # let document = parseHTML(res.bodyStream)
  let document = loadHtml("examples/hn.html")
  # var stack = @[Node(document)]
  # echo "document: ", document.findAll("table")
  var submissions: seq[XmlNode]
  for tr in document.findAll("tr"):
    # athing submission
    if tr.attrs != nil and tr.attrs.hasKey "class":
      if tr.attrs["class"] == "athing submission":
        submissions.add tr

  for submission in submissions:
    echo "story: "
    echo submission
    echo ""

    # # echo "table: ", table
    # echo "table: ", table.attrs
    # if table.attrs.hasKey("id"):
    #   if table.attrs["id"] == "hnmain":
    #     # table.findAll("tbody")
    #     # echo "main: ", table
    #     let comments = table.elems().toSeq()[1]
    #     let comments = 
    #     echo "stories: "


when isMainModule:
  let l = HtmlLoader(url: "https://news.ycombinator.com")
  l.loadPage()
