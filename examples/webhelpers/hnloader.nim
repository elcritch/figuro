import sigils
import std/httpclient
import std/os
import std/sequtils
import std/strutils
import std/hashes
# import chame/minidom
import std/xmltree
import std/strtabs
import pkg/htmlparser

type HtmlLoader* = ref object of Agent

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

  Link* = object
    title*: string
    href*: string
    siteFrom*: string
    siteName*: string

  SubText* = object
    votes*: int
    user*: string
    time*: string
    comments*: int

  Submission* = ref object
    rank*: string
    upvote*: Upvote
    link*: Link
    subText*: SubText

proc hash*(s: Submission): Hash =
  if s.isNil:
    result = 0
  else:
    result = s.link.href.hash

type
  TableSubmission = ref object
    subTr*: XmlNode
    subTextTr*: XmlNode

proc htmlDone*(tp: HtmlLoader, stories: seq[Submission]) {.signal.}

proc loadPage*(loader: HtmlLoader, url: string) {.slot.} =
  try:
    echo "Starting page load..."
    when false and isMainModule:
      let document = loadHtml("examples/hn.html")
    else:
      let client = newHttpClient()
      let res = client.get(url)
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

    var submissions: seq[Submission]
    for sub in subs:
      var submission = Submission()
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

      if sub.subTextTr != nil:
        let points = sub.subTextTr.findAll("span").withAttrs({"class": "score"}).getFirst(true)
        if points != nil:
          let points = points.innerText().split(" ")
          submission.subText.votes = parseInt(points[0])

        let user = sub.subTextTr.findAll("a").withAttrs({"class": "hnuser"}).getFirst(true)
        if user != nil:
          submission.subText.user = user.innerText()

        let time = sub.subTextTr.findAll("span").withAttrs({"class": "age"}).getFirst(true)
        if time != nil:
          submission.subText.time = time.innerText()

        let comments = sub.subTextTr.findAll("a")
        for comment in comments:
          if comment.innerText().endsWith("comments"):
            var txt = comment.innerText().replace("&nbsp;", " ").replace("\194\160", " ")
            let txts = txt.split(" ")
            submission.subText.comments = parseInt(txts[0])

      submissions.add(submission)

    # for sub in submissions:
    #   echo $sub
    emit loader.htmlDone(submissions)
  except CatchableError as err:
    echo "error loading page: ", $err.msg
    echo "error loading page: ", $err.getStackTrace()
  except Defect as err:
    echo "error loading page: ", $err.msg
    echo "error loading page: ", $err.getStackTrace()

proc markdownDone*(tp: HtmlLoader, url: string, markdown: string) {.signal.}

import readability

proc loadPageMarkdown*(loader: HtmlLoader, url: string) {.slot.} =
  try:
    echo "Starting page load with url: ", url
    if url.endsWith(".pdf"):
      raise newException(ValueError, "PDFs are not supported")

    when false and isMainModule:
      let document = loadHtml("examples/hn.html")
    else:
      let client = newHttpClient(timeout=1_000)
      let res = client.get(url)


    when true:
      let document = parseHTML(res.body)
      let reader = newReadability(document)
      let result = reader.parse()
      let markdown = result["content"]
      emit loader.markdownDone(url, markdown)
    else:
      # Create a process to run html2markdown
      var markdown = ""
      try:
        let process = startProcess(
          "html2markdown",
          options={poUsePath, poStdErrToStdOut}
        )

        # Write HTML to stdin of html2markdown
        process.inputStream.write(res.body)
        process.inputStream.close()

        # Read markdown from stdout
        markdown = process.outputStream.readAll()
        process.close()
      except OSError as err:
        echo "error running html2markdown: ", $err.msg
        echo "error running html2markdown: ", $err.getStackTrace()
        markdown = "error running html2markdown:\n" & $err.msg
        markdown.add "try installing html2markdown: https://github.com/JohannesKaufmann/html-to-markdown"

      when isMainModule:
        echo "markdown:\n", markdown

      emit loader.markdownDone(url, markdown) # Emit the markdown result
  except CatchableError as err:
    echo "error loading page: ", $err.msg
    echo "error loading page: ", $err.getStackTrace()
    emit loader.markdownDone(url, "error loading page: " & $err.msg) # Emit the markdown result
  except Defect as err:
    echo "error loading page: ", $err.msg
    echo "error loading page: ", $err.getStackTrace()
    emit loader.markdownDone(url, "error loading page: " & $err.msg) # Emit the markdown result

when isMainModule:
  let l = HtmlLoader()
  l.loadPage("https://news.ycombinator.com")

  let m = HtmlLoader()
  m.loadPageMarkdown("https://example.com")
