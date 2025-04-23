import ../commons
import pkg/sigils/weakrefs
import pkg/chronicles

template has(val: Atom): bool =
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

  trace "selector:check: ", sel = sel, selRepr = sel.repr, node = node.uid, name = node.name
  if has(sel.id):
    if sel.id == node.name:
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

  trace "selector:pseudo:check: ", pseudo = pseudo, pseudoRepr = pseudo.repr, node = node.uid, name = node.name
  case $pseudo.cssType
  of "hover":
    if evHover in node.events:
      result = true
  of "active":
    if Active in node.userAttrs:
      result = true
  of "focus":
    if Focus in node.userAttrs:
      result = true
  of "focus-visible":
    if FocusVisible in node.userAttrs:
      result = true
  of "focus-within":
    if FocusWithin in node.userAttrs:
      result = true
  of "open":
    if Open in node.userAttrs:
      result = true
  of "selected":
    if Selected in node.userAttrs:
      result = true
  of "disabled":
    if Disabled in node.userAttrs:
      result = true
  else:
    once:
      warn "unhandled CSS psuedo class: ", cssPseudo = pseudo.cssType
    result = false
 
  if result:
    trace "cssengine:matched pseudo", node= $node.name, pseudo= pseudo.cssType
  else:
    trace "cssengine:failed pseudo", node= $node.name, pseudo= pseudo.cssType

proc colorValue(value: CssValue, values: CssValues): Color =
  match value:
    CssColor(c):
      result = c
    CssVarName(n):
      trace "cssengine:colorValue: ", names= values.names, values= values.values
      var res: CssValue
      if values.resolveVariable(n, res):
        result = colorValue(res, values)
      else:
        result = blackColor
    _:
      result = blackColor

proc sizeValue(value: CssValue, values: CssValues): Constraint =
  match value:
    CssSize(cx):
      result = cx
    CssVarName(n):
      var res: CssValue
      if values.resolveVariable(n, res):
        result = sizeValue(res, values)
      else:
        result = Constraint(kind: UiNone)
        raise newException(ValueError, "css expected size! Got: " & $value)
    _:
      raise newException(ValueError, "css expected size! Got: " & $value)

proc shadowValue(value: CssValue, values: CssValues): tuple[sstyle: ShadowStyle, sx, sy, sblur, sspread: Constraint, scolor: Color] =
  match value:
    CssShadow(style, x, y, blur, spread, color):
      result = (style, x, y, blur, spread, color)
    CssVarName(n):
      var res: CssValue
      if values.resolveVariable(n, res):
        result = shadowValue(res, values)
      else:
        result = (InnerShadow, Constraint(kind: UiNone), Constraint(kind: UiNone), Constraint(kind: UiNone), Constraint(kind: UiNone), clearColor)
        raise newException(ValueError, "css expected size! Got: " & $value)
    _:
      raise newException(ValueError, "css expected size! Got: " & $value)

proc apply*(prop: CssProperty, node: Figuro, values: CssValues) =
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

  var pname = $prop.name
  if pname.startsWith("--"):
    pname = pname[2..^1]
    trace "cssengine:apply:setVariable:", varName = pname
    let idx = values.registerVariable(pname.toAtom())
    values.setVariable(idx, prop.value)
    return

  case pname
  of "color":
    # is color in CSS really only for fonts?
    let color = colorValue(prop.value, values)
    if node of Text:
      # for child in node.children:
      node.fill = color
    else:
      for child in node.children:
        if child of Text:
          # for gc in child.children:
          child.fill = color
  of "background", "background-color", "-fig-fill":
    let color = colorValue(prop.value, values)
    node.fill = color
  of "border-color":
    let color = colorValue(prop.value, values)
    node.stroke.color = color
  of "border-width":
    let cx = sizeValue(prop.value, values)
    setCxFixed(cx, node.stroke.weight)
  of "border-radius", "-fig-cornerRadius":
    let cx = sizeValue(prop.value, values)
    setCxFixed(cx, node.cornerRadius, UiScalar)
  of "width":
    let cx = sizeValue(prop.value, values)
    node.cxSize[dcol] = cx
  of "height":
    let cx = sizeValue(prop.value, values)
    node.cxSize[drow] = cx
  of "left":
    let cx = sizeValue(prop.value, values)
    node.cxOffset[dcol] = cx
  of "top":
    let cx = sizeValue(prop.value, values)
    node.cxOffset[drow] = cx
  of "min-width":
    let cx = sizeValue(prop.value, values)
    node.cxMin[dcol] = cx
  of "min-height":
    let cx = sizeValue(prop.value, values)
    node.cxMin[drow] = cx
  of "max-width":
    let cx = sizeValue(prop.value, values)
    node.cxMax[dcol] = cx
  of "max-height":
    let cx = sizeValue(prop.value, values)
    node.cxMax[drow] = cx
  of "padding":
    let cx = sizeValue(prop.value, values)
    node.cxPadOffset[dcol] = cx
    node.cxPadOffset[drow] = cx
    node.cxPadSize[dcol] = cx
    node.cxPadSize[drow] = cx
  of "padding-left":
    let cx = sizeValue(prop.value, values)
    node.cxPadOffset[dcol] = cx
  of "padding-right":
    let cx = sizeValue(prop.value, values)
    node.cxPadSize[dcol] = cx
  of "padding-top":
    let cx = sizeValue(prop.value, values)
    node.cxPadOffset[drow] = cx
  of "padding-bottom":
    let cx = sizeValue(prop.value, values)
    node.cxPadSize[drow] = cx
  of "padding-horizontal":
    let cx = sizeValue(prop.value, values)
    node.cxPadOffset[dcol] = cx
    node.cxPadSize[drow] = cx
  of "padding-vertical":
    let cx = sizeValue(prop.value, values)
    node.cxPadOffset[drow] = cx
    node.cxPadSize[dcol] = cx
  of "box-shadow":
    let shadow = shadowValue(prop.value, values)
    let style = shadow.sstyle
    setCxFixed(shadow.sx, node.shadow[style].x, UiScalar)
    setCxFixed(shadow.sy, node.shadow[style].y, UiScalar)
    setCxFixed(shadow.sblur, node.shadow[style].blur, UiScalar)
    setCxFixed(shadow.sspread, node.shadow[style].spread, UiScalar)
    node.shadow[style].color = shadow.scolor
  else:
    debug "cssengine", error= "unhandled css property", propertyName= prop.name
    discard

proc eval*(rule: CssBlock, node: Figuro, values: CssValues) =
  trace "### eval:", node= node.name, wn= node.widgetName, sel=rule.selectors.len
  trace "rule: ", selectors = rule.selectors, selRepr = rule.selectors.repr

  var
    sel: CssSelector
    matched = true
    prevCombinator = skNone
    currNode = node  # Keep track of which node we're currently matching against

  for i in 1 .. rule.selectors.len():
    sel = rule.selectors[^i]
    trace "SEL: ", sel = sel, comb = $prevCombinator

    if sel.combinator == skPseudo:
      if prevCombinator == skNone and sel.cssType in [atom"root", atom"default"]:
        if values != nil and not values.applied.contains(sel.cssType):
          matched = true
          values.applied.incl sel.cssType
        else:
          matched = false
        continue

      prevCombinator = sel.combinator
      continue

    case prevCombinator
    of skNone, skSelectorList:
      trace "skNone/SelList:: ", prevCombinator = $prevCombinator
      matched = matched and sel.checkMatch(currNode)
      if not matched:
        trace "not matched", name = currNode.name, wn = currNode.widgetName, sel = sel
        break
    of skPseudo:
      # info "skPseudo: ", prevCombinator = $prevCombinator
      matched = matched and sel.checkMatch(currNode)
      matched = matched and rule.selectors[^(i-1)].checkMatchPseudo(currNode)
      if not matched:
        # info "not matched", name = node.name, wn = node.widgetName, sel = sel
        break
    of skDirectChild:
      if currNode.parent.isNil:
        matched = false
        break
      else:
        withRef currNode.parent, parent:
          currNode = parent  # Move up to the parent
          matched = matched and sel.checkMatch(currNode)
          if not matched:
            trace "not matched (parent)", name = currNode.name, wn = currNode.widgetName, sel = sel
            break
    of skDescendent:
      var parentMatched = false
      for p in currNode.parents():
        trace "sel:p: ", parentUid = p.uid, name = p.name, wn = p.widgetName
        parentMatched = sel.checkMatch(p)
        if parentMatched:
          currNode = p  # Set the current node to the matched parent
          trace "sel:p:matched ", name = p.name, wn = p.widgetName, sel = sel
          break
      matched = matched and parentMatched
      if not matched:
        break

    trace "selMatch: ", matched = matched, idx = i
    prevCombinator = sel.combinator

  if matched:
    trace "cssengine", name= node.name, matchedNode= node.uid, rule= rule
    for prop in rule.properties:
      prop.apply(node, values)

proc applyThemeRules*(node: Figuro) =
  # echo "\n=== Theme: ", node.getId(), " name: ", node.name, " class: ", node.widgetName
  for (path, theme) in node.frame[].theme.css:
    let values = theme.values
    if SkipCss in node.userAttrs:
      return
    let node = if node of Text: node.parent[] else: node
    for rule in rules(theme):
      rule.eval(node, values)
