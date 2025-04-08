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

  # echo "selector:pseudo:check: ", pseudo.repr, " node: ", node.uid, " name: ", node.name
  case pseudo.cssType
  of "hover":
    if evHover in node.events:
      result = true
  of "active":
    if Active in node.userAttrs:
      result = true
  of "focused":
    if Focused in node.userAttrs:
      result = true
  of "selected":
    if Selected in node.userAttrs:
      result = true
  of "enabled":
    if Enabled in node.userAttrs:
      result = true
  of "disabled":
    if Disabled in node.userAttrs:
      result = true
  else:
    once:
      echo "Warning: ", "unhandled CSS psuedo class: ", pseudo.cssType
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
      info "cssengine:colorValue: ", names= values.names, values= values.values
      var res: CssValue
      if values.resolveVariable(n, res):
        result = colorValue(res, values)
      else:
        result = clearColor
        raise newException(ValueError, "css expected color! Got: " & repr(value))
    _:
      raise newException(ValueError, "css expected color! Got: " & repr(value))

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

  if prop.name.startsWith("--"):
    let varName = prop.name.substr(2)
    notice "cssengine:apply:setVariable:", varName = varName
    let idx = values.registerVariable(varName)
    values.setVariable(idx, prop.value)
    return

  case prop.name
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
  of "background", "background-color":
    let color = colorValue(prop.value, values)
    node.fill = color
  of "border-color":
    let color = colorValue(prop.value, values)
    node.stroke.color = color
  of "border-width":
    let cx = sizeValue(prop.value, values)
    setCxFixed(cx, node.stroke.weight)
  of "border-radius":
    let cx = sizeValue(prop.value, values)
    setCxFixed(cx, node.cornerRadius, UiScalar)
  of "width":
    let cx = sizeValue(prop.value, values)
    node.cxSize[dcol] = cx
  of "height":
    let cx = sizeValue(prop.value, values)
    node.cxSize[drow] = cx
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
      if prevCombinator == skNone and sel.cssType == "root":
        if values != nil and not values.rootApplied:
          matched = true
          values.rootApplied = true
        else:
          matched = false
        continue

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
      prop.apply(node, values)

proc applyThemeRules*(node: Figuro) =
  # echo "\n=== Theme: ", node.getId(), " name: ", node.name, " class: ", node.widgetName
  assert not node.frame[].theme.css.isNil
  assert not node.frame[].theme.css.values.isNil
  let values = node.frame[].theme.css.values
  if SkipCss in node.userAttrs:
    return
  let node = if node of Text: node.parent[] else: node
  for rule in rules(node.frame[].theme.css):
    rule.eval(node, values)
