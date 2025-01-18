import sigils
import std/httpclient
import std/os
import std/sequtils
import std/strutils
import std/sugar

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

iterator withAttrs*(n: openArray[XmlNode], attrs: varargs[string]): XmlNode {.inline.} =
  for c in n:
    if c.kind == xnElement and c.attrs != nil:
      var filt = true
      for attr in attrs:
        filt = filt and c.attrs.hasKey(attr)
      if filt:
        yield c

iterator withAttrs*(n: openArray[XmlNode], attrs: openArray[(string, string)]): XmlNode {.inline.} =
  for c in n:
    if c.kind == xnElement and c.attrs != nil:
      var filt = true
      for attr in attrs:
        filt = filt and
        c.attrs.hasKey(attr[0]) and 
        c.attrs[attr[0]] == attr[1]
      if filt:
        yield c

type
  Upvote* = object
    id*: string
    href*: string
  Submission* = object
    rank*: string
    upvote*: Upvote

proc loadPage(loader: HtmlLoader) {.slot.} =
  echo "Starting page load..."
  let client = newHttpClient()
  let document = loadHtml("examples/hn.html")
  var subs: seq[XmlNode] =
    document.
      findAll("tr").
      withAttrs({"class": "athing submission"}).toSeq()

  var submissions: seq[Submission]
  for sub in subs[0..1]:
    var submission: Submission
    echo "story: "
    echo sub
    let rank = sub.
      findAll("span").
      withAttrs({"class": "rank"}).
      toSeq()[0]
    let vote = sub.findAll("a").withAttrs("id").toSeq()[0]
    submission.rank = rank.innerText()
    submission.upvote.id = vote.attrs["id"]
    submission.upvote.href = vote.attrs["href"]
    echo "\nsubmission: ", repr submission
    echo ""


when isMainModule:
  let l = HtmlLoader(url: "https://news.ycombinator.com")
  l.loadPage()
