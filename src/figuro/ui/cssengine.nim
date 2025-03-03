import ../commons
import pkg/sigils/weakrefs
import pkg/chronicles

template has(val: string): bool =
  val.len() > 0

iterator parents*(node: Figuro): Figuro =
  var curr = node
  var cnt = 0
  while not curr.parent.isNil() and curr.unsafeWeakRef() != curr.parent:
    withRef curr.parent, parent:
      curr = parent
      yield curr
      cnt.inc
      if cnt > 1_000:
        raise newException(IndexDefect, "error finding root")

proc checkMatch*(sel: CssSelector, node: Figuro): bool =
  ## checks a CSS selector in a "fail fast" style
  ## so it'll return false unless every check passes
  result = false

  # echo "selector:check: ", sel.repr, " node: ", node.uid, " name: ", node.name
  if has(sel.id):
    if sel.id in node.name:
      # echo "matched class! node: ", $node
      discard
    else:
      # echo "failed id check"
      return

  if has(sel.cssType):
    if node.widgetName == sel.cssType:
      # echo "matched type! node: ", $node
      discard
    else:
      # echo "failed type check"
      return

  if has(sel.class):
    if sel.class in node.widgetClasses:
      # echo "matched class! node: ", $node
      discard
    else:
      # echo "failed class check"
      return

  # if node.combinator == skPseudo and node. 

  return true

proc checkMatchPseudo*(pseudo: CssSelector, node: Figuro): bool =
  ## checks a CSS selector in a "fail fast" style
  ## so it'll return false unless every check passes
  result = false

  # echo "selector:pseudo:check: ", pseudo.repr, " node: ", node.uid, " name: ", node.name
  case pseudo.cssType
  of "hover":
    if evHover in node.events:
      # echo "matched pseudo hover! node: ", $node.name
      discard
    else:
      # echo "failed pseudo hover! node: ", $node.name, " evt: ", node.events
      return
  else:
    once:
      echo "Warning: ", "unhandled CSS psuedo class: ", pseudo.cssType
    

  # if node.combinator == skPseudo and node. 

  return true

proc colorValue(value: CssValue): Color =
  match value:
    CssColor(c):
      result = c
    CssVarName(n):
      try:
        result = parseHtmlColor(n)
      except InvalidColor:
        raise newException(ValueError, "not a css color!")
    _:
      raise newException(ValueError, "css expected color! Got: " & $value)

proc sizeValue(value: CssValue): Constraint =
  match value:
    CssSize(cx):
      result = cx
    _:
      raise newException(ValueError, "css expected size! Got: " & $value)

proc shadowValue(value: CssValue): tuple[sstyle: ShadowStyle, sx, sy, sblur, sspread: Constraint, scolor: Color] =
  match value:
    CssShadow(style, x, y, blur, spread, color):
      result = (style, x, y, blur, spread, color)
    _:
      raise newException(ValueError, "css expected size! Got: " & $value)

proc apply*(prop: CssProperty, node: Figuro) =
  trace "cssengine:apply", uid= node.uid, name= node.name, wn= node.widgetName, prop= prop.repr

  template setCxFixed(cx, field: untyped, tp = float32) =
    match cx:
      UiValue(value):
        match value:
          UiFixed(coord):
            field = coord.tp
          _:
            discard
        discard
      _:
        discard

  case prop.name
  of "color":
    # is color in CSS really only for fonts?
    let color = colorValue(prop.value)
    if node of Text:
      # for child in node.children:
      node.fill = color
    else:
      for child in node.children:
        if child of Text:
          # for gc in child.children:
          child.fill = color
  of "background", "background-color":
    let color = colorValue(prop.value)
    node.fill = color
  of "border-color":
    let color = colorValue(prop.value)
    node.stroke.color = color
  of "border-width":
    let cx = sizeValue(prop.value)
    setCxFixed(cx, node.stroke.weight)
  of "border-radius":
    let cx = sizeValue(prop.value)
    setCxFixed(cx, node.cornerRadius, UiScalar)
  of "width":
    let cx = sizeValue(prop.value)
    node.cxSize[dcol] = cx
  of "height":
    let cx = sizeValue(prop.value)
    node.cxSize[drow] = cx
  of "box-shadow":
    let shadow = shadowValue(prop.value)
    let style = shadow.sstyle
    setCxFixed(shadow.sx, node.shadow[style].x, UiScalar)
    setCxFixed(shadow.sy, node.shadow[style].y, UiScalar)
    setCxFixed(shadow.sblur, node.shadow[style].blur, UiScalar)
    setCxFixed(shadow.sspread, node.shadow[style].spread, UiScalar)
    node.shadow[style].color = shadow.scolor
  else:
    debug "cssengine", error= "unhandled css property", propertyName= prop.name
    discard

import std/terminal

proc eval*(rule: CssBlock, node: Figuro) =
  # print rule.selectors
  # stdout.styledWriteLine fgGreen, "\n### eval:node:: ", node.name, " wn: ", node.widgetName, " sel:len: ", $rule.selectors.len
  # stdout.styledWriteLine fgRed, rule.selectors.repr

  var
    sel: CssSelector
    matched = true
    prevCombinator = skNone
    # curr = node

  for i in 1 .. rule.selectors.len():
    sel = rule.selectors[^i]
    # stdout.styledWriteLine fgBlue, "SEL: ", sel.repr, fgYellow, " comb: ", $prevCombinator

    if sel.combinator == skPseudo:
      prevCombinator = sel.combinator
      continue

    case prevCombinator
    of skNone, skSelectorList:
      # stdout.styledWriteLine fgCyan, "skNone/SelList:: ", $prevCombinator
      matched = matched and sel.checkMatch(node)
      if not matched:
        # echo "not matched"
        break
    of skPseudo:
      # stdout.styledWriteLine fgCyan, "skPseudo: ", $prevCombinator
      matched = matched and sel.checkMatch(node)
      matched = matched and rule.selectors[^(i-1)].checkMatchPseudo(node)
      if not matched:
        # echo "not matched"
        break
    of skDirectChild:
      if node.parent.isNil:
        matched = false
      else:
        matched = matched and sel.checkMatch(node.parent[])
    of skDescendent:
      var parentMatched = false
      for p in node.parents():
        # echo "sel:p: ", p.uid
        parentMatched = sel.checkMatch(p)
        if parentMatched:
          # echo "sel:p:matched "
          break
      matched = matched and parentMatched

    # echo "selMatch: ", matched, " idx: ", i, "\n"
    prevCombinator = sel.combinator

  if matched:
    trace "cssengine", name= node.name, matchedNode= node.uid, rule= rule
    # print rule.selectors
    # echo "setting properties:"
    for prop in rule.properties:
      # print rule.properties
      prop.apply(node)

proc applyThemeRules*(node: Figuro) =
  # echo "\n=== Theme: ", node.getId(), " name: ", node.name, " class: ", node.widgetName
  if skipCss in node.attrs:
    return
  let node = if node of Text: node.parent[] else: node
  for rule in rules(node.frame[].theme.css):
    rule.eval(node)
