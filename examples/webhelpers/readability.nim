import std/[htmlparser, xmltree, streams, strutils, strtabs, re, tables, math, sets]
import readabilitytypes

export readabilitytypes

# Additional helper methods for readability
proc cleanConditionally(self: Readability, e: XmlNode, tag: string) =
  if not self.flagIsActive(CleanConditionally):
    return

  self.removeNodes(self.getAllNodesWithTag(e, [tag]),
    proc(node: XmlNode): bool =
      # Check if this node IS data table, in which case don't remove it
      if tag == "table" and node.hasAttr("readability-data-table") and
         node.attr("readability-data-table") == "true":
        return false

      # Get score (if it has one)
      let score = try: parseInt(node.attr("readability-score")) except: 0
      let linkDensity = self.getLinkDensity(node)

      # Simplified scoring - remove elements with low scores or high link density
      if score < 0:
        self.log("Removing element due to negative score: " & $score)
        return true

      # Remove high link density elements
      if linkDensity > 0.5 + self.linkDensityModifier:
        self.log("Removing element due to high link density: " & $linkDensity)
        return true

      # Get number of commas
      let innerText = self.getInnerText(node)
      let commas = innerText.count(",")
      if commas < 10:
        # Check for special conditions when there aren't many commas

        # Count images
        let imgCount = self.getAllNodesWithTag(node, ["img"]).len

        # Count paragraphs
        let pCount = self.getAllNodesWithTag(node, ["p"]).len

        # If few commas and more images than paragraphs, remove
        if imgCount > pCount:
          self.log("Removing element with more images than paragraphs")
          return true

        let innerText = self.getInnerText(node)

        if innerText.len < 25 and imgCount == 0:
          self.log("Removing short content element with no images")
          return true

        if find(innerText, REGEXPS_adWords) >= 0:
          self.log("Removing element with ad words")
          return true

        if find(innerText, REGEXPS_loadingWords) >= 0:
          self.log("Removing element with loading words")
          return true

      return false
  )

proc cleanClasses(self: Readability, node: XmlNode) =
  # Keep only classes that match classesToPreserve
  let className = node.attr("class")
  if className.len > 0:
    var classNames = className.split(" ")
    var newClassNames: seq[string] = @[]

    for cls in classNames:
      if cls in self.classesToPreserve:
        newClassNames.add(cls)

    # Apply the filtered class names
    if newClassNames.len > 0:
      # Would update the class attribute
      self.log("Would set class to: " & newClassNames.join(" "))
    else:
      # Would remove the class attribute
      self.log("Would remove class attribute")

  # Process children
  for i in 0..<node.len:
    if node[i].kind == xnElement:
      self.cleanClasses(node[i])

proc cleanHeaders(self: Readability, e: XmlNode) =
  # Remove headers with low class weight
  let headingNodes = self.getAllNodesWithTag(e, ["h1", "h2"])
  self.removeNodes(headingNodes,
    proc(node: XmlNode): bool =
      let shouldRemove = self.getClassWeight(node) < 0
      if shouldRemove:
        self.log("Removing header with low class weight: " & node.tag)
      return shouldRemove
  )

proc fixLazyImages(self: Readability, articleContent: XmlNode) =
  # Convert lazy-loaded images to standard images
  let imageNodes = self.getAllNodesWithTag(articleContent, ["img", "picture", "figure"])

  for elem in imageNodes:
    # Check if this is a lazy-loaded image
    if elem.attr("data-src").len > 0:
      # Would copy data-src to src
      self.log("Would copy data-src to src: " & elem.attr("data-src"))
    elif elem.attr("data-srcset").len > 0:
      # Would copy data-srcset to srcset
      self.log("Would copy data-srcset to srcset")
    elif elem.attr("class").contains("lazy"):
      # Look for other attributes that might contain the real image URL
      for key, value in elem.attrs.pairs:
        if key.startsWith("data-") and (value.endsWith(".jpg") or
                                       value.endsWith(".jpeg") or
                                       value.endsWith(".png") or
                                       value.endsWith(".webp")):
          # Would set appropriate attribute
          self.log("Would set src to: " & value)
          break

proc markDataTables(self: Readability, root: XmlNode) =
  # Mark tables that are likely to be data tables vs layout tables
  let tables = self.getAllNodesWithTag(root, ["table"])

  for table in tables:
    # Check presentation role
    if table.attr("role") == "presentation":
      table.attrs["readability-data-table"] = "false"
      continue

    # Check datatable attribute
    if table.attr("datatable") == "0":
      table.attrs["readability-data-table"] = "false"
      continue

    # Check for summary
    if table.attr("summary").len > 0:
      table.attrs["readability-data-table"] = "true"
      continue

    # Check for caption
    let captions = self.getAllNodesWithTag(table, ["caption"])
    if captions.len > 0 and self.getInnerText(captions[0]).len > 0:
      table.attrs["readability-data-table"] = "true"
      continue

    # Simplified check for data table elements
    let dataTableElements = ["col", "colgroup", "tfoot", "thead", "th"]
    var hasDataElements = false

    for tagName in dataTableElements:
      if self.getAllNodesWithTag(table, [tagName]).len > 0:
        hasDataElements = true
        break

    if hasDataElements:
      table.attrs["readability-data-table"] = "true"
      continue

    # If table has nested tables, it's likely a layout table
    if self.getAllNodesWithTag(table, ["table"]).len > 0:
      table.attrs["readability-data-table"] = "false"
      continue

    # Check for rows and columns
    let rows = self.getAllNodesWithTag(table, ["tr"])
    if rows.len > 10:
      table.attrs["readability-data-table"] = "true"
      continue

    let cols = if rows.len > 0: self.getAllNodesWithTag(rows[0], ["td", "th"]).len else: 0
    if cols > 4:
      table.attrs["readability-data-table"] = "true"
      continue

    # Otherwise it's likely a layout table
    table.attrs["readability-data-table"] = "false"


# Clean style and presentational attributes from elements
proc cleanStyles*(self: Readability, e: XmlNode) =
  # Skip empty nodes or SVG elements
  if e.isNil or e.tag == "SVG":
    return

  # Remove presentational attributes
  for attr in PRESENTATIONAL_ATTRIBUTES:
    if e.hasAttr(attr):
      # Remove the attribute
      e.attrs.del(attr)

  # Remove width and height attributes for specific elements
  if e.tag in DEPRECATED_SIZE_ATTRIBUTE_ELEMS:
    if e.hasAttr("width"):
      e.attrs.del("width")
    if e.hasAttr("height"):
      e.attrs.del("height")

  # Recursively process children
  for i in 0..<e.len:
    if e[i].kind == xnElement:
      self.cleanStyles(e[i])

# Clean out elements with tag name while preserving videos
proc clean*(self: Readability, e: XmlNode, tag: string) =
  let isEmbed = ["object", "embed", "iframe"].contains(tag)

  self.removeNodes(
    self.getAllNodesWithTag(e, [tag]),
    proc(element: XmlNode): bool =
      # Allow youtube and vimeo videos through as people usually want to see those
      if isEmbed:
        # Check attributes for video URLs
        for key, value in element.attrs.pairs:
          if find(value, REGEXPS_videos) >= 0:
            return false  # Keep video embed

        # For embed with <object> tag, check inner HTML as well
        if element.tag == "OBJECT":
          let content = getInnerText(self, element)
          if find(content, REGEXPS_videos) >= 0:
            return false  # Keep video object

      # Remove all other elements of this tag type
      return true
  )

proc prepArticle(self: Readability) =
  # Clean out inline styles
  self.cleanStyles(self.doc)

  # Mark data tables before continuing
  # self.markDataTables(articleContent)

  # Fix lazy loaded images
  # self.fixLazyImages(articleContent)

  # Clean out junk from the article content
  # self.cleanConditionally(articleContent, "form")
  # self.cleanConditionally(articleContent, "fieldset")
  self.clean(self.doc, "object")
  self.clean(self.doc, "embed")
  self.clean(self.doc, "footer")
  self.clean(self.doc, "link")
  self.clean(self.doc, "aside")

  # Clean share elements
  let shareElementThreshold = self.charThreshold

  # Clean iframes, input, forms, etc.
  self.clean(self.doc, "iframe")
  self.clean(self.doc, "input")
  self.clean(self.doc, "textarea")
  self.clean(self.doc, "select")
  self.clean(self.doc, "button")
  self.clean(self.doc, "script")
  # self.cleanHeaders(articleContent)

  # Do these last as the previous steps may have removed junk
  self.cleanConditionally(self.doc, "table")
  self.cleanConditionally(self.doc, "ul")
  self.cleanConditionally(self.doc, "div")

  # Replace H1 with H2
  self.replaceNodeTags(
    self.getAllNodesWithTag(self.doc, ["h1"]),
    "h2"
  )

  # Remove extra paragraphs
  self.removeNodes(
    self.getAllNodesWithTag(self.doc, ["p"]),
    proc(paragraph: XmlNode): bool =
      var contentElementCount = self.getAllNodesWithTag(paragraph, [
        "img",
        "embed",
        "object",
        "iframe",
      ]).len
      return contentElementCount == 0 and self.getInnerText(paragraph, false).strip() == ""
  )

  filterNodes(self.doc)

proc postProcessContent(self: Readability) =
  # Fix relative URIs

  # Remove classes if keepClasses is false
  # if not self.keepClasses:
  #   self.cleanClasses(self.doc)
  discard

proc simplifyNestedElements(self: Readability) =
  # Due to limitations in Nim's XmlNode traversal,
  # this is a simplified implementation of the simplifyNestedElements method
  self.log("Would simplify nested elements for better readability")

proc initializeNode(self: Readability, node: XmlNode) =
  if not node.hasAttr("readability-score"):
    node.setAttr("readability-score", "0")

  var score = 0

  # Add to score based on tag
  case node.tag.toLowerAscii()
  of "div":
    score += 5
  of "pre", "td", "blockquote":
    score += 3
  of "address", "ol", "ul", "dl", "dd", "dt", "li", "form":
    score -= 3
  of "h1", "h2", "h3", "h4", "h5", "h6", "th":
    score -= 5
  else:
    discard

  # Add class/ID weight
  score += self.getClassWeight(node)

  # Store score
  node.attrs["readability-score"] = $score

proc grabArticle(self: Readability, page: XmlNode = nil) =
  self.log("**** grabArticle ****")

  var pageToParse =
    if page != nil:
      page
    else:
      let res = self.doc.findAllSafe("body")
      if res.len > 0:
        res[0]
      else:
        newElement("body")

  if pageToParse == nil:
    self.log("No body found in document. Abort.")
    return

  # Create a new node to store the article content

  # Simplify nested elements to improve readability
  simplifyNestedElements(self, self.doc)


  # For a proper implementation, we need to:
  # 1. Score paragraphs and other elements in the page
  # 2. Find the highest-scoring element as our top candidate
  # 3. Get siblings that might have related content
  # 4. Clean the article content

  # For simplicity, in this implementation we'll just identify
  # and keep the main content elements

  # Identify candidate elements - paragraphs, divs with text, etc.
  var elementsToScore: HashSet[XmlNode] = initHashSet[XmlNode]()

  for elem in pageToParse.findAllSafe("p"):
    # If paragraph has reasonable text length, consider it
    if self.getInnerText(elem).len >= 25:
      elementsToScore.incl(elem)

  for elem in pageToParse.findAllSafe("div"):
    # Divs that are like paragraphs (no block elements inside)
    if not self.hasChildBlockElement(elem):
      elementsToScore.incl(elem)

  # Score each element and put top candidates in articleContent
  for elem in elementsToScore:
    self.initializeNode(elem)
    let score = parseInt(elem.attr("readability-score"))

    # If score is above threshold, include in article
    if score <= 0:
      # echo "setting:KEEPING: " & $elem.tag & " attrs: " & $elem.attrs
      elem.setAttr("keep", "true")

  self.doc = keepNodes(self.doc)

  # If we haven't extracted any meaningful content, return nil
  # let textLength = self.getInnerText(articleContent, true).len
  # if textLength < self.charThreshold:
  #   return nil

  # Clean and prepare the article content for display
  self.prepArticle()

proc parse*(self: Readability): Table[string, string] =
  # Avoid parsing too large documents, as per configuration option
  if self.maxElemsToParse > 0:
    let numTags = self.doc.findAll("*").len
    if numTags > self.maxElemsToParse:
      raise newException(ValueError,
        "Aborting parsing document; " & $numTags & " elements found"
      )

  # Prepare the document by removing junk elements
  self.prepDocument()

  # Get article metadata
  self.articleTitle = self.getArticleTitle()

  # Extract the main article content
  self.grabArticle()

  # Post-process the article content
  self.postProcessContent()

  # Convert the article content to string
  let title = newElement("h2")
  title.add(newText(self.articleTitle))
  self.doc.insert([title], 0)

  var content = $self.doc

  # Clean smart quotes and special characters
  content = content.multireplace({
    "": "\"",
    "'": "'",
    " ": " ",
    " ": " ",
    "—": "--",
    "–": "-",
    "…": "...",
    "•": "*",
    "©": "(c)",
    "®": "(R)",
    "™": "(TM)",
    "×": "x",
    "&amp;": "&",
    "&quot;": "\"",
    "&apos;": "'",
    "&lt;": "<",
    "&gt;": ">",
    "&nbsp;": " ",
    "&shy;": "",
    "&mdash;": "--",
    "&ldquo;": "\"",
    "&rdquo;": "\"",
    "&lsquo;": "'",
    "&rsquo;": "'",
    "&hellip;": "...",
    "&middot;": "*",
    "&times;": "x",
    "&copy;": "(c)",
    "&reg;": "(R)",
    "&trade;": "(TM)",
    "&bull;": "*",
    "&middot;": "*",
    "&hellip;": "...",
  })

  var textContent = self.getInnerText(self.doc)

  # Return the result
  # echo "TITLE: " & self.articleTitle
  var result = {
    "title": self.articleTitle,
    "content": content,
    "textContent": textContent,
    "length": $textContent.len,
    "byline": self.articleByline,
    "dir": self.articleDir,
    "siteName": self.articleSiteName
  }.toTable

  for key, value in self.metadata:
    result[key] = value

  return result

# Convenience function to parse HTML and extract readable content
proc extractReadableContent*(html: string, options: Table[string, string] = initTable[string, string]()): Table[string, string] =
  try:
    let doc = parseHtml(newStringStream(html))
    let reader = newReadability(doc, options)
    return reader.parse()
  except:
    return {"error": getCurrentExceptionMsg()}.toTable

when isMainModule:
  when false:
    # let url = "https://blog.arduino.cc/2025/03/17/this-diy-experimental-reactor-harnesses-the-birkeland-eyde-process/"
    let url = "https://tomscii.sig7.se/2025/04/The-Barium-Experiment"
    let client = newHttpClient()
    let res = client.get(url)
    let html = res.body
  else:
    let html = readFile("examples/readability-test-input.html")
  let document = parseHTML(html)
  let reader = newReadability(document)
  let result = reader.parse()
  echo result["content"]
