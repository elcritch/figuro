import sigils
import std/httpclient
import std/os
import std/strutils

import chame/minidom
import pretty

type HtmlLoader* = ref object of Agent
  url: string


proc loadPage(loader: HtmlLoader) {.slot.} =
  echo "Starting page load..."
  let client = newHttpClient()
  let res = client.get(loader.url)
  let document = parseHTML(res.bodyStream)
  var stack = @[Node(document)]
  while stack.len > 0:
    let node = stack.pop()
    if node of minidom.Text:
      let s = minidom.Text(node)
      echo "text: ", s.data.strip()
    elif node of minidom.Element:
      let elem = minidom.Element(node)
      echo "element: ", elem.localNameStr()
    for i in countdown(node.childList.high, 0):
      stack.add(node.childList[i])

when isMainModule:
  let l = HtmlLoader(url: "https://news.ycombinator.com")
  l.loadPage()
