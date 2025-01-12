import ../../ui/basiccss
import ui
import pkg/pretty
import pkg/sigils/weakrefs

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

proc apply*(prop: CssProperty, node: Figuro) =
  # echo "\napply node: ", node.uid, " ", node.name, " prop: ", prop.repr

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

  match prop.value:
    MissingCssValue:
      raise newException(ValueError, "missing css value!")
    CssColor(c):
      # echo "\tapply color: ", c.repr
      case prop.name
      of "background":
        node.fill = c
      of "border-color":
        node.stroke.color = c
      else:
        # echo "warning: ", "unhandled css property: ", prop.repr
        discard
    CssSize(cx):
      # echo "\tapply size: ", cx.repr
      case prop.name
      of "border-width":
        setCxFixed(cx, node.stroke.weight)
      of "border-radius":
        setCxFixed(cx, node.cornerRadius, UICoord)
      else:
        # echo "warning: ", "unhandled css property: ", prop.repr
        discard
    CssVarName(n):
      once:
        echo "Warning: ", "unhandled css variable: ", prop.repr

import std/terminal

proc eval*(rule: CssBlock, node: Figuro) =
  # print rule.selectors
  stdout.styledWriteLine fgGreen, "\n### eval:node:: ", node.name, " wn: ", node.widgetName, " sel:len: ", $rule.selectors.len
  stdout.styledWriteLine fgRed, rule.selectors.repr

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
    # echo "matched node: ", node.uid
    # print rule.selectors
    # echo "setting properties:"
    for prop in rule.properties:
      # print rule.properties
      prop.apply(node)

proc applyThemeRules*(node: Figuro) =
  # echo "\n=== Theme: ", node.getId(), " name: ", node.name, " class: ", node.widgetName
  if not node.frame[].theme.isNil:
    for rule in node.frame[].theme.cssRules:
      rule.eval(node)
