import std/[htmlparser, algorithm, xmltree, hashes, strutils, strtabs, sequtils, re, tables, uri, math, sets]

# Readability.nim - A port of Mozilla's Readability library to Nim
#
# Note on implementation limitations:
# This is a partial port of Readability.js to Nim. The main limitation is that
# Nim's standard XmlNode type doesn't track parent-child relationships or siblings
# in the same way as DOM nodes in JavaScript. This means certain operations like
# tree traversal and node removal don't work the same way.
#
# Several methods are implemented as stubs with appropriate comments where
# parent/sibling tracking would be required for full functionality.
#
# In a complete implementation, you would need to either:
# 1. Modify Nim's XmlNode to track parent references
# 2. Maintain a separate data structure for tracking node relationships
# 3. Use an alternative HTML/XML parser with better tree traversal support

type
  Flags* = enum
    StripUnlikelys = 0
    WeightClasses = 1
    CleanConditionally = 2

  Readability* = ref object
    doc*: XmlNode
    articleTitle*: string
    articleByline*: string
    articleDir*: string
    articleSiteName*: string
    attempts*: seq[tuple[articleContent: XmlNode, textLength: int]]
    metadata*: Table[string, string]
    
    # Configurable options
    debug*: bool
    maxElemsToParse*: int
    nbTopCandidates*: int
    charThreshold*: int
    classesToPreserve*: seq[string]
    keepClasses*: bool
    disableJSONLD*: bool
    linkDensityModifier*: float
    flags*: set[Flags]

# Constants
const
  DEFAULT_MAX_ELEMS_TO_PARSE* = 0
  DEFAULT_N_TOP_CANDIDATES* = 5
  DEFAULT_CHAR_THRESHOLD* = 500
  DEFAULT_TAGS_TO_SCORE* = @["SECTION", "H2", "H3", "H4", "H5", "H6", "P", "TD", "PRE"]
  
  CLASSES_TO_PRESERVE* = @["page"]
  
  DIV_TO_P_ELEMS* = @["BLOCKQUOTE", "DL", "DIV", "IMG", "OL", "P", "PRE", "TABLE", "UL"]
  
  ALTER_TO_DIV_EXCEPTIONS* = @["DIV", "ARTICLE", "SECTION", "P", "OL", "UL"]
  
  PRESENTATIONAL_ATTRIBUTES* = @[
    "align", "background", "bgcolor", "border", "cellpadding", "cellspacing", 
    "frame", "hspace", "rules", "style", "valign", "vspace"
  ]
  
  DEPRECATED_SIZE_ATTRIBUTE_ELEMS* = @["TABLE", "TH", "TD", "HR", "PRE"]
  
  PHRASING_ELEMS* = @[
    "ABBR", "AUDIO", "B", "BDO", "BR", "BUTTON", "CITE", "CODE", "DATA", "DATALIST", 
    "DFN", "EM", "EMBED", "I", "IMG", "INPUT", "KBD", "LABEL", "MARK", "MATH", "METER", 
    "NOSCRIPT", "OBJECT", "OUTPUT", "PROGRESS", "Q", "RUBY", "SAMP", "SCRIPT", "SELECT", 
    "SMALL", "SPAN", "STRONG", "SUB", "SUP", "TEXTAREA", "TIME", "VAR", "WBR"
  ]
  
  UNLIKELY_ROLES* = @[
    "menu", "menubar", "complementary", "navigation", "alert", "alertdialog", "dialog"
  ]

# Regular expressions
let 
  REGEXPS_unlikelyCandidates* = re"(?i)-ad-|ai2html|banner|breadcrumbs|combx|comment|community|cover-wrap|disqus|extra|footer|gdpr|header|legends|menu|related|remark|replies|rss|shoutbox|sidebar|skyscraper|social|sponsor|supplemental|ad-break|agegate|pagination|pager|popup|yom-remote"
  REGEXPS_okMaybeItsACandidate* = re"(?i)and|article|body|column|content|main|mathjax|shadow"
  REGEXPS_positive* = re"(?i)article|body|content|entry|hentry|h-entry|main|page|pagination|post|text|blog|story"
  REGEXPS_negative* = re"(?i)-ad-|hidden|^hid$| hid$| hid |^hid |banner|combx|comment|com-|contact|footer|gdpr|masthead|media|meta|outbrain|promo|related|scroll|share|shoutbox|sidebar|skyscraper|sponsor|shopping|tags|widget"
  REGEXPS_extraneous* = re"(?i)print|archive|comment|discuss|e[\-]?mail|share|reply|all|login|sign|single|utility"
  REGEXPS_byline* = re"(?i)byline|author|dateline|writtenby|p-author"
  REGEXPS_replaceFonts* = re"(?i)<(\/?)font[^>]*>"
  REGEXPS_normalize* = re"\s{2,}"
  REGEXPS_videos* = re"\/\/(www\.)?((dailymotion|youtube|youtube-nocookie|player\.vimeo|v\.qq|bilibili|live.bilibili)\.com|(archive|upload\.wikimedia)\.org|player\.twitch\.tv)"
  REGEXPS_shareElements* = re"(?i)(\b|_)(share|sharedaddy)(\b|_)"
  REGEXPS_nextLink* = re"(?i)(next|weiter|continue|>([^\|]|$)|»([^\|]|$))"
  REGEXPS_prevLink* = re"(?i)(prev|earl|old|new|<|«)"
  REGEXPS_tokenize* = re"\W+"
  REGEXPS_whitespace* = re"^\s*$"
  REGEXPS_hasContent* = re"\S$"
  REGEXPS_hashUrl* = re"^#.+"
  REGEXPS_srcsetUrl* = re"(\S+)(\s+[\d.]+[xw])?(\s*(?:,|$))"
  REGEXPS_b64DataUrl* = re"^data:\s*([^\s;,]+)\s*;\s*base64\s*,"
  REGEXPS_jsonLdArticleTypes* = re"^Article|AdvertiserContentArticle|NewsArticle|AnalysisNewsArticle|AskPublicNewsArticle|BackgroundNewsArticle|OpinionNewsArticle|ReportageNewsArticle|ReviewNewsArticle|Report|SatiricalArticle|ScholarlyArticle|MedicalScholarlyArticle|SocialMediaPosting|BlogPosting|LiveBlogPosting|DiscussionForumPosting|TechArticle|APIReference$"
  REGEXPS_adWords* = re"(?i)^(ad(vertising|vertisement)?|pub(licité)?|werb(ung)?|广告|Реклама|Anuncio)$"
  REGEXPS_loadingWords* = re"(?i)^((loading|正在加载|Загрузка|chargement|cargando)(…|\.\.\.)?)$"
  # REGEXPS_adWords* = re"(?iu)^(ad(vertising|vertisement)?|pub(licité)?|werb(ung)?|广告|Реклама|Anuncio)$"
  # REGEXPS_loadingWords* = re"(?iu)^((loading|正在加载|Загрузка|chargement|cargando)(…|\.\.\.)?)$"

# Forward declarations of functions
proc log*(self: Readability, args: varargs[string, `$`])
proc flagIsActive*(self: Readability, flag: Flags): bool
proc getInnerText*(self: Readability, e: XmlNode, normalizeSpaces: bool = true): string
proc getCharCount*(self: Readability, e: XmlNode, s: string = ","): int
proc getClassWeight*(self: Readability, e: XmlNode): int
proc getLinkDensity*(self: Readability, element: XmlNode): float
proc getNextNode*(self: Readability, node: XmlNode, ignoreSelfAndKids: bool = false): XmlNode
proc removeAndGetNext*(self: Readability, node: XmlNode): XmlNode
proc getAllNodesWithTag*(self: Readability, node: XmlNode, tagNames: openArray[string]): seq[XmlNode]
proc forEachNode*(self: Readability, nodeList: seq[XmlNode], fn: proc(node: XmlNode))
proc findNode*(self: Readability, nodeList: seq[XmlNode], fn: proc(node: XmlNode): bool): XmlNode
proc someNode*(self: Readability, nodeList: seq[XmlNode], fn: proc(node: XmlNode): bool): bool
proc everyNode*(self: Readability, nodeList: seq[XmlNode], fn: proc(node: XmlNode): bool): bool
proc setNodeTag*(self: Readability, node: XmlNode, tag: string): XmlNode
proc removeNodes*(self: Readability, nodeList: seq[XmlNode], filterFn: proc(node: XmlNode): bool = nil)
proc replaceNodeTags*(self: Readability, nodeList: seq[XmlNode], newTagName: string)
proc isPhrasingContent*(self: Readability, node: XmlNode): bool
proc isWhitespace*(self: Readability, node: XmlNode): bool
proc isElementWithoutContent*(self: Readability, node: XmlNode): bool
proc hasChildBlockElement*(self: Readability, element: XmlNode): bool
proc hasSingleTagInsideElement*(self: Readability, element: XmlNode, tag: string): bool
proc textSimilarity*(self: Readability, textA, textB: string): float
proc hasAncestorTag*(self: Readability, node: XmlNode, tagName: string, maxDepth: int = 3, 
                   filterFn: proc(node: XmlNode): bool = nil): bool
proc isProbablyVisible*(self: Readability, node: XmlNode): bool
proc prepDocument*(self: Readability)
proc getArticleTitle*(self: Readability): string


proc hash*(self: XmlAttributes): Hash =
  result = 0
  for key, val in self.pairs:
    result = result * 31 + key.hash()
    result = result * 31 + val.hash()

proc hash*(self: XmlNode): Hash =
  result = cast[Hash](self)
  # if self.kind == xnElement:
  #   for child in self:
  #     result = result !& child.hash()
  #   result = result !& self.tag.hash()
  #   if not self.attrs.isNil:
  #     result = result !& self.attrs.hash()
  # if self.kind in {xnText, xnVerbatimText, xnComment, xnCData, xnEntity}:
  #   result = result !& self.text.hash()
  # result = !$ result

proc findAllSafe*(node: XmlNode, tag: string, caseInsensitive = false): seq[XmlNode] =
  if node.kind == xnElement:
    result = node.findAll(tag, caseInsensitive = true)

# Implementation of helper functions
proc log*(self: Readability, args: varargs[string, `$`]) =
  if self.debug:
    echo args.join(" ")

proc hasAttr*(e: XmlNode, attr: string): bool =
  if e.isNil or e.attrs.isNil:
    return false
  return e.attrs.hasKey(attr)

proc getAttr*(e: XmlNode, attr: string): string =
  if e.attrs.isNil:
    return ""
  if not e.attrs.hasKey(attr):
    return ""
  return e.attrs[attr]

proc setAttr*(e: XmlNode, attr: string, value: string) =
  if e.attrs.isNil:
    e.attrs = newStringTable()
  e.attrs[attr] = value

proc flagIsActive*(self: Readability, flag: Flags): bool =
  return flag in self.flags

proc getInnerText*(self: Readability, e: XmlNode, normalizeSpaces: bool = true): string =
  if e == nil:
    return ""
    
  var textContent = ""
  for n in e:
    if n.kind == xnText:
      textContent.add(n.text)
    elif n.kind == xnElement:
      textContent.add(self.getInnerText(n, normalizeSpaces))
  
  textContent = textContent.strip()
  
  if normalizeSpaces:
    # Replace 2 or more spaces with a single space
    textContent = replace(textContent, REGEXPS_normalize, " ")
  
  return textContent

proc getCharCount*(self: Readability, e: XmlNode, s: string = ","): int =
  let innerText = self.getInnerText(e)
  return innerText.split(s).len - 1

proc getClassWeight*(self: Readability, e: XmlNode): int =
  if not self.flagIsActive(WeightClasses):
    return 0
  
  var weight = 0
  
  # Look for a special classname
  let className = e.attr("class")
  if className != "":
    if find(className, REGEXPS_negative) >= 0:
      weight -= 25
    
    if find(className, REGEXPS_positive) >= 0:
      weight += 25
  
  # Look for a special ID
  let id = e.attr("id")
  if id != "":
    if find(id, REGEXPS_negative) >= 0:
      weight -= 25
    
    if find(id, REGEXPS_positive) >= 0:
      weight += 25
  
  return weight

proc getLinkDensity*(self: Readability, element: XmlNode): float =
  let textLength = self.getInnerText(element).len
  if textLength == 0:
    return 0.0
  
  var linkLength = 0
  for linkNode in self.getAllNodesWithTag(element, ["a"]):
    let href = linkNode.attr("href")
    var coefficient = 1.0
    if href != "" and find(href, REGEXPS_hashUrl) >= 0:
      coefficient = 0.3
    linkLength += int(float(self.getInnerText(linkNode).len) * coefficient)
  
  return linkLength.float / textLength.float

proc getAllNodesWithTag*(self: Readability, node: XmlNode, tagNames: openArray[string]): seq[XmlNode] =
  for tag in tagNames:
    if node.kind == xnElement:
      result.add(node.findAllSafe(tag, caseInsensitive = true))


proc forEachNode*(self: Readability, nodeList: seq[XmlNode], fn: proc(node: XmlNode)) =
  for node in nodeList:
    fn(node)

proc findNode*(self: Readability, nodeList: seq[XmlNode], fn: proc(node: XmlNode): bool): XmlNode =
  for node in nodeList:
    if fn(node):
      return node
  return nil

proc someNode*(self: Readability, nodeList: seq[XmlNode], fn: proc(node: XmlNode): bool): bool =
  for node in nodeList:
    if fn(node):
      return true
  return false

proc everyNode*(self: Readability, nodeList: seq[XmlNode], fn: proc(node: XmlNode): bool): bool =
  for node in nodeList:
    if not fn(node):
      return false
  return true

proc getNextNode*(self: Readability, node: XmlNode, ignoreSelfAndKids: bool = false): XmlNode =
  # Note: This is a simplified version as Nim's XmlNode doesn't track parent nodes
  # First check for kids if those aren't being ignored
  if not ignoreSelfAndKids and node.len > 0:
    for i in 0..<node.len:
      if node[i].kind == xnElement:
        return node[i]
  
  # For a more complete implementation, we would need to track parent-child 
  # relationships separately or modify the XmlNode structure
  return nil

proc removeAndGetNext*(self: Readability, node: XmlNode): XmlNode =
  # In a complete implementation, we would need to remove the node
  # from its parent and return the next node
  # Since we don't have proper parent tracking, this is a stub
  return nil

proc filterChildren*(node: XmlNode) =
    # Define a recursive function to filter children
    # Skip empty nodes
    if node.isNil:
      return
    
    # Return as-is if this is a text node
    if node.kind in {xnText, xnVerbatimText, xnComment, xnCData, xnEntity}:
      return
    
    # Process children recursively, excluding removed nodes
    var childrenToRemove: seq[int] = @[]
    for i in 0..<node.len:
      if node[i].kind == xnElement and node[i].attr("remove") == "true":
        childrenToRemove.add(i)
    
    for i in childrenToRemove.reversed():
      # echo "REMOVING: " & $node[i].tag & " attrs: " & $node[i].attrs
      node.delete(i)
    
    for child in node:
      filterChildren(child)
  

proc removeNodes*(self: Readability, nodeList: seq[XmlNode], filterFn: proc(node: XmlNode): bool = nil) =
  ## Actually removes nodes from the XML tree by recursively reconstructing parent nodes
  ## This works despite Nim's XmlNode not tracking parent-child relationships
  
  # Create a hash set of nodes to be removed for faster lookups
  if filterFn == nil:
    # If no filter function is provided, mark all nodes in nodeList for removal
    for node in nodeList:
      setAttr(node, "remove", "true")
  else:
    # If a filter function is provided, only mark nodes that match the filter
    for node in nodeList:
      if filterFn(node):
        setAttr(node, "remove", "true")
  
  # Skip if there's nothing to remove
  if nodeList.len == 0:
    return
  
  filterChildren(self.doc)

proc filterNodes*(node: XmlNode) =
  var nodeIdxsToRemove: seq[int] = @[]
  for i in 0..<node.len:
    if node[i].kind == xnElement:
      if node[i].getAttr("keep") != "true":
        nodeIdxsToRemove.add(i)
  for i in nodeIdxsToRemove.reversed():
    node.delete(i)
  
  for child in node:
    if child.kind == xnElement:
      filterNodes(child)

proc keepNodes*(node: XmlNode): XmlNode =
  result = newElement("div")
  result.setAttr("id", "readability-content")

  proc keepNodesInner(node: XmlNode): seq[XmlNode] =
    result = @[]
    if node.kind != xnElement:
      result.add(node)
      return result

    for child in node:
      if child.kind == xnElement:
        if child.getAttr("keep") == "true":
          # This node should be kept - create a copy with its attributes
          var newNode = newElement(child.tag)
          if not child.attrs.isNil:
            for attr in child.attrs.pairs:
              newNode.setAttr(attr[0], attr[1])
          
          # Add only text children directly from this node
          for textChild in child:
            # echo "TEXT CHILD: " & $textChild
            if textChild.kind == xnText:
              newNode.add(textChild)
          
          # Also look for nested keep=true nodes
          let keptChildren = keepNodesInner(child)
          for keptChild in keptChildren:
            newNode.add(keptChild)
          
          result.add(newNode)
          # echo "KEEPING: " & $child.tag & " attrs: " & $child.attrs
        else:
          # This node doesn't have keep=true, but check its children
          let keptChildren = keepNodesInner(child)
          for keptChild in keptChildren:
            result.add(keptChild)
    
    return result
  
  result.add(keepNodesInner(node)) 

proc replaceNodeTags*(self: Readability, nodeList: seq[XmlNode], newTagName: string) =
  for node in nodeList:
    discard self.setNodeTag(node, newTagName)

proc setNodeTag*(self: Readability, node: XmlNode, tag: string): XmlNode =
  # Create a new node with the same attributes and children but different tag
  result = newElement(tag)
  
  # Copy attributes
  if not node.attrs.isNil:
    result.attrs = newStringTable()
    for key, val in node.attrs.pairs:
      result.attrs[key] = val
  
  # Copy children
  for child in node:
    result.add(child)
  
  # Note: In a complete implementation, we would need to replace this node
  # in its parent's children list
  return result

proc isPhrasingContent*(self: Readability, node: XmlNode): bool =
  if node.kind == xnText:
    return true
  
  if node.kind != xnElement:
    return false
  
  if node.tag in PHRASING_ELEMS:
    return true
  
  if node.tag in ["A", "DEL", "INS"]:
    # Check if all children are phrasing content
    for child in node:
      if not self.isPhrasingContent(child):
        return false
    return true
  
  return false

proc isWhitespace*(self: Readability, node: XmlNode): bool =
  if node.kind == xnText and node.text.strip().len == 0:
    return true
  
  if node.kind == xnElement and node.tag == "BR":
    return true
  
  return false

proc isElementWithoutContent*(self: Readability, node: XmlNode): bool =
  if node.kind != xnElement:
    return false
  
  let innerText = self.getInnerText(node).strip()
  if innerText.len > 0:
    return false
  
  var brCount = 0
  var hrCount = 0
  for child in node:
    if child.kind == xnElement:
      if child.tag == "BR":
        brCount += 1
      elif child.tag == "HR":
        hrCount += 1
  
  return node.len == brCount + hrCount

proc hasChildBlockElement*(self: Readability, element: XmlNode): bool =
  for node in element:
    if node.kind == xnElement:
      if node.tag in DIV_TO_P_ELEMS:
        return true
      if self.hasChildBlockElement(node):
        return true
  return false

proc hasSingleTagInsideElement*(self: Readability, element: XmlNode, tag: string): bool =
  # There should be exactly 1 element child with given tag
  var elemCount = 0
  var targetNode: XmlNode = nil
  
  for child in element:
    if child.kind == xnElement:
      elemCount += 1
      if child.tag == tag:
        targetNode = child
      if elemCount > 1:
        return false
  
  if targetNode == nil or elemCount != 1:
    return false
  
  # And there should be no text nodes with real content
  for node in element:
    if node.kind == xnText and not match(node.text, REGEXPS_whitespace):
      return false
  
  return true

proc textSimilarity*(self: Readability, textA, textB: string): float =
  let tokensA = textA.toLowerAscii().split(REGEXPS_tokenize).filterIt(it.len > 0)
  let tokensB = textB.toLowerAscii().split(REGEXPS_tokenize).filterIt(it.len > 0)
  
  if tokensA.len == 0 or tokensB.len == 0:
    return 0.0
  
  let uniqTokensB = tokensB.filterIt(it notin tokensA)
  let distanceB = uniqTokensB.join(" ").len.float / tokensB.join(" ").len.float
  
  return 1.0 - distanceB

proc hasAncestorTag*(self: Readability, node: XmlNode, tagName: string, maxDepth: int = 3, 
                   filterFn: proc(node: XmlNode): bool = nil): bool =
  # Note: Since we don't have parent tracking in Nim's XmlNode,
  # this is a stub implementation that always returns false
  self.log("hasAncestorTag would check if node has ancestor with tag: ", tagName)
  return false
  
  # In a complete implementation with parent tracking:
  # let upperTag = tagName.toUpperAscii()
  # var depth = 0
  # var current = node
  # 
  # while current.parent != nil:
  #   if maxDepth > 0 and depth > maxDepth:
  #     return false
  #   
  #   if current.parent.kind == xnElement and current.parent.tag == upperTag:
  #     if filterFn == nil or filterFn(current.parent):
  #       return true
  #   
  #   current = current.parent
  #   depth += 1
  # 
  # return false

proc isProbablyVisible*(self: Readability, node: XmlNode): bool =
  if node.kind != xnElement:
    return true
  
  if node.attr("style").contains("display:none") or 
     node.attr("style").contains("visibility:hidden"):
    return false
  
  if node.attr("hidden") != "":
    return false
  
  if node.attr("aria-hidden") == "true":
    # Exception for wikimedia math images
    if node.attr("class").contains("fallback-image"):
      return true
    return false
  
  return true

# Main Readability object constructor
proc newReadability*(doc: XmlNode, options: Table[string, string] = initTable[string, string]()): Readability =
  new(result)
  result.doc = doc
  result.articleTitle = ""
  result.articleByline = ""
  result.articleDir = ""
  result.articleSiteName = ""
  result.attempts = @[]
  result.metadata = initTable[string, string]()
  
  # Set default options
  result.debug = options.getOrDefault("debug") == "true"
  result.maxElemsToParse = if options.hasKey("maxElemsToParse"): parseInt(options["maxElemsToParse"]) else: DEFAULT_MAX_ELEMS_TO_PARSE
  result.nbTopCandidates = if options.hasKey("nbTopCandidates"): parseInt(options["nbTopCandidates"]) else: DEFAULT_N_TOP_CANDIDATES
  result.charThreshold = if options.hasKey("charThreshold"): parseInt(options["charThreshold"]) else: DEFAULT_CHAR_THRESHOLD
  result.classesToPreserve = if options.hasKey("classesToPreserve"): options["classesToPreserve"].split(",") else: CLASSES_TO_PRESERVE
  result.keepClasses = options.getOrDefault("keepClasses") == "true"
  result.disableJSONLD = options.getOrDefault("disableJSONLD") == "true"
  result.linkDensityModifier = if options.hasKey("linkDensityModifier"): parseFloat(options["linkDensityModifier"]) else: 0.0
  
  # Set flags
  result.flags = {StripUnlikelys, WeightClasses, CleanConditionally}

proc prepDocument*(self: Readability) =
  # Remove all style tags in head
  self.removeNodes(self.getAllNodesWithTag(self.doc, ["style"]))
  
  # Replace all font tags with span
  self.replaceNodeTags(self.getAllNodesWithTag(self.doc, ["font"]), "SPAN")
  
  # Replace BRs 
  # Note: In a complete implementation, we would replace consecutive <br> tags with <p>
  # This would require proper tracking of siblings, which Nim's XmlNode doesn't provide
  self.log("Would replace consecutive BR elements if we had sibling tracking")
  
  if self.doc.findAllSafe("body").len > 0:
    # In the complete implementation, we would call replaceBrs here
    discard

proc getArticleTitle*(self: Readability): string =
  var doc = self.doc
  var curTitle = ""
  var origTitle = ""
  
  try:
    let titleElements = doc.findAllSafe("title")
    if titleElements.len > 0:
      origTitle = self.getInnerText(titleElements[0]).strip()
      curTitle = origTitle
  except:
    return ""
  
  # Check for separator in title
  var titleHadHierarchicalSeparators = false
  
  proc wordCount(s: string): int =
    return s.split(REGEXPS_whitespace).len
  
  let titleSeparators = r"\|\-–—\\\/>»"
  let titleSeparatorsRegex = re("\\s[" & titleSeparators & "]\\s")
  
  if find(curTitle, titleSeparatorsRegex) >= 0:
    titleHadHierarchicalSeparators = find(curTitle, re"\\s[\\\/>»]\\s") >= 0
    
    # Split by separator and use first part
    let parts = curTitle.split(titleSeparatorsRegex)
    
    if parts.len > 0:
      curTitle = parts[0]
    
    # If resulting title is too short, use the last part instead
    if wordCount(curTitle) < 3 and parts.len > 1:
      curTitle = parts[^1]
  
  elif curTitle.contains(": "):
    # Check if we have a heading containing this exact string
    let headings = self.getAllNodesWithTag(doc, ["h1", "h2"])
    let trimmedTitle = curTitle.strip()
    
    var matchFound = false
    for heading in headings:
      if self.getInnerText(heading).strip() == trimmedTitle:
        matchFound = true
        break
    
    # If no match found, extract title after the colon
    if not matchFound:
      let parts = curTitle.split(":")
      if parts.len > 1:
        curTitle = parts[^1].strip()
        
        # If title is now too short, try using the part before the colon
        if wordCount(curTitle) < 3:
          curTitle = parts[0].strip()
  
  # If title is too long or too short, look for H1
  elif curTitle.len > 150 or curTitle.len < 15:
    let h1s = doc.findAllSafe("h1")
    if h1s.len == 1:
      curTitle = self.getInnerText(h1s[0])
  
  # Clean up title
  curTitle = curTitle.strip().replace(REGEXPS_normalize, " ")
  
  # If title is now very short, use the original title
  let curTitleWordCount = wordCount(curTitle)
  if curTitleWordCount <= 4 and not titleHadHierarchicalSeparators:
    curTitle = origTitle
  
  return curTitle
