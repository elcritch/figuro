
import ../../ui/basiccss
import ui
import pretty

template has(val: string): bool =
  val.len() > 0

iterator parents*(node: Figuro): Figuro =
  var curr = node
  var cnt = 0
  while not curr.parent.isNil() and curr.unsafeWeakRef() != curr.parent:
    curr = curr.parent.toRef
    yield curr
    cnt.inc
    if cnt > 10_000:
      raise newException(IndexDefect, "error finding root")

proc apply*(sel: CssSelector, node: Figuro): bool =
  result = false

  echo "selector:check: ", sel.repr, " node: ", node.uid, " name: ", node.name
  if has(sel.id):
    if sel.id in node.name:
      echo "matched class! node: ", $node
    else:
      echo "failed id check"
      return

  if has(sel.cssType): 
    if node.widgetName == sel.cssType:
      echo "matched type! node: ", $node
    else:
      echo "failed type check"
      return

  if has(sel.class):
    if sel.class in node.widgetClasses:
      echo "matched class! node: ", $node
    else:
      echo "failed class check"
      return
  
  return true

proc apply*(rule: CssBlock, node: Figuro) =
  # print rule.selectors

  var
    sel: CssSelector
    matched = true
    combinator = skNone
    curr = node

  for i in 1 .. rule.selectors.len():
    sel = rule.selectors[^i]
    print "SEL: ", sel
    print "comb: ", combinator
    case combinator:
    of skNone, skPseudo:
      matched = matched and sel.apply(node)
      if not matched:
        echo "not matched"
        break
    of skDescendent:
      var parentMatched = false
      for p in node.parents():
        echo "sel:p: ", p.uid
        parentMatched = sel.apply(p)
        if parentMatched:
          echo "sel:p:matched "
          break
      matched = matched and parentMatched
    else:
      echo "unhandled combinator type! type: ", combinator.repr

    echo "selMatch: ", matched, " idx: ", i, "\n"
    combinator = sel.combinator

proc applyThemeRules*(node: Figuro) =
  echo "\n=== Theme: ", node.getId(), " name: ", node.name, " class: ", node.widgetName
  if not node.frame.theme.isNil:
    for rule in node.frame.theme.cssRules:
      rule.apply(node)
