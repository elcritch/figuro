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
  url*: string

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

iterator withAttrs*(
    n: openArray[XmlNode], attrs: openArray[(string, string)]
): XmlNode {.inline.} =
  for c in n:
    if c.kind == xnElement and c.attrs != nil:
      var filt = true
      for attr in attrs:
        filt = filt and c.attrs.hasKey(attr[0]) and attr[1] in c.attrs[attr[0]]
      if filt:
        yield c

proc hasAttr*(n: XmlNode, attr: string): bool =
  if n.attrs.isNil:
    return false
  return n.attrs.hasKey(attr)

proc getAttr*(n: XmlNode, attr: string, default = ""): string =
  if n.attrs.isNil:
    result = default
  else:
    result = n.attrs[attr]

template getFirst(item: untyped, doNil = false): auto =
  let s = item.toSeq()
  if s.len == 0:
    if doNil:
      nil.XmlNode
    else:
      raise newException(ValueError, "no item found for " & astToStr(item))
  else:
    s[0]


type
  Upvote* = object
    id*: string
    href*: string
    votes*: int

  Link* = object
    title*: string
    href*: string
    siteFrom*: string
    siteName*: string

  Submission* = object
    rank*: string
    upvote*: Upvote
    link*: Link

  TableSubmission* = ref object
    subTr*: XmlNode
    subTextTr*: XmlNode

proc htmlDone*(tp: HtmlLoader, stories: seq[Submission]) {.signal.}

proc loadPage*(loader: HtmlLoader) {.slot.} =
  try:
    echo "Starting page load..."
    when false and isMainModule:
      let document = loadHtml("examples/hn.html")
    else:
      let client = newHttpClient()
      let res = client.get(loader.url)
      let document = parseHTML(res.bodyStream)

    let table: XmlNode = document.findAll("table").toSeq()[2]

    echo "TABLE: "
    var subs: seq[TableSubmission]
    var sub: TableSubmission = nil
    for elem in table.elems():

      if "submission" in getAttr(elem, "class"):
        if sub != nil: subs.add(move sub)
        sub = TableSubmission(subTr: elem)
      
      if sub != nil and elem.attrs == nil:
        sub.subTextTr = elem

    echo "SUBS: "
    for sub in subs:
      echo "SUB: ", sub.subTr == nil, " ", sub.subTextTr == nil

    # var subs: seq[XmlNode] =
    #   table.findAll("tr").withAttrs({"class": "athing submission"}).toSeq()

    var submissions: seq[Submission]
    for sub in subs:
      var submission: Submission
      # echo "story:\n\t", sub
      let rank = sub.subTr.findAll("span").withAttrs({"class": "rank"}).getFirst()
      let vote = sub.subTr.findAll("a").withAttrs("id").getFirst(doNil=true)
      let titleTd = sub.subTr.findAll("span").withAttrs({"class": "titleline"}).getFirst()
      let linkA = titleTd.elems().getFirst()
      let siteSpan = sub.subTr.findAll("span").withAttrs({"class": "sitebit"}).getFirst(doNil=true)

      submission.link.href = linkA.attrs["href"]
      submission.link.title = linkA.innerText()
      if siteSpan != nil:
        submission.link.siteFrom = siteSpan.findAll("a")[0].attrs["href"]
        submission.link.siteName = siteSpan.findAll("span")[0].innerText()

      submission.rank = rank.innerText()
      if vote != nil:
        submission.upvote.id = vote.attrs["id"]
        submission.upvote.href = vote.attrs["href"]

      submissions.add(submission)
    
    emit loader.htmlDone(submissions)
  except CatchableError as err:
    echo "error loading page: ", $err.msg
    echo "error loading page: ", $err.getStackTrace()
  except Defect as err:
    echo "error loading page: ", $err.msg
    echo "error loading page: ", $err.getStackTrace()


when isMainModule:
  let l = HtmlLoader(url: "https://news.ycombinator.com")
  l.loadPage()
