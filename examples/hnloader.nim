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

type
  Upvote* = object
    id*: string
    href*: string

  Link* = object
    title*: string
    href*: string
    siteFrom*: string
    siteName*: string

  Submission* = object
    rank*: string
    upvote*: Upvote
    link*: Link

proc loadPage*(loader: HtmlLoader) {.slot.} =
  echo "Starting page load..."
  when isMainModule:
    let document = loadHtml("examples/hn.html")
  else:
    let client = newHttpClient()
    let res = client.get(loader.url)
    let document = parseHTML(res.bodyStream)
  var subs: seq[XmlNode] =
    document.findAll("tr").withAttrs({"class": "athing submission"}).toSeq()

  var submissions: seq[Submission]
  for sub in subs[0 .. 1]:
    var submission: Submission
    # echo "story: "
    # echo sub
    let rank = sub.findAll("span").withAttrs({"class": "rank"}).toSeq()[0]
    let vote = sub.findAll("a").withAttrs("id").toSeq()[0]
    let titleTd = sub.findAll("span").withAttrs({"class": "titleline"}).toSeq()[0]
    let linkA = titleTd.elems().toSeq()[0]
    let siteSpan = sub.findAll("span").withAttrs({"class": "sitebit"}).toSeq()[0]
    submission.link.href = linkA.attrs["href"]
    submission.link.title = linkA.innerText()
    submission.link.siteFrom = siteSpan.findAll("a")[0].attrs["href"]
    submission.link.siteName = siteSpan.findAll("span")[0].innerText()

    submission.rank = rank.innerText()
    submission.upvote.id = vote.attrs["id"]
    submission.upvote.href = vote.attrs["href"]
    # echo ""
    # echo "siteSpan: ", siteSpan
    # echo ""
    echo "\nsubmission:\n\t", repr submission
    # echo ""

when isMainModule:
  let l = HtmlLoader(url: "https://news.ycombinator.com")
  l.loadPage()
