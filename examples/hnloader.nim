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

proc loadPage(loader: HtmlLoader) {.slot.} =
  echo "Starting page load..."
  let client = newHttpClient()
  # let res = client.get(loader.url)
  # let document = parseHTML(res.bodyStream)
  let document = loadHtml("examples/hn.html")
  # var stack = @[Node(document)]
  # echo "document: ", document.findAll("table")
  for table in document.findAll("table"):
    echo "table: ", table
    if table.attrs.hasKey "hnmain":
      # table.findAll("tbody")
      # echo "main: ", table
      for child in table:
        echo "child: ", child.htmlTag

when isMainModule:
  let l = HtmlLoader(url: "https://news.ycombinator.com")
  l.loadPage()
