
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

proc checkMatch*(sel: CssSelector, node: Figuro): bool =
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
      case prop.name:
      of "background":
        node.fill = c
      of "border-color":
        node.stroke.color = c
      else:
        echo "warning: ", "unhandled css property: ", prop.repr
    CssSize(cx):
      # echo "\tapply size: ", cx.repr
      case prop.name:
      of "border-width":
        setCxFixed(cx, node.stroke.weight)
      of "border-radius":
        setCxFixed(cx, node.cornerRadius, UICoord)
      else:
        echo "warning: ", "unhandled css property: ", prop.repr
    CssVarName(n):
      echo "warning: ", "unhandled css variable: ", prop.repr


proc eval*(rule: CssBlock, node: Figuro) =
  # print rule.selectors

  var
    sel: CssSelector
    matched = true
    combinator = skNone
    # curr = node

  for i in 1 .. rule.selectors.len():
    sel = rule.selectors[^i]
    # print "SEL: ", sel
    # print "comb: ", combinator
    case combinator:
    of skNone, skPseudo:
      matched = matched and sel.checkMatch(node)
      if not matched:
        # echo "not matched"
        break
    of skDirectChild:
      if node.parent.isNil:
        matched = false
      else:
        matched = matched and sel.checkMatch(node.parent.toRef)

    of skDescendent:
      var parentMatched = false
      for p in node.parents():
        # echo "sel:p: ", p.uid
        parentMatched = sel.checkMatch(p)
        if parentMatched:
          # echo "sel:p:matched "
          break
      matched = matched and parentMatched
    else:
      echo "unhandled combinator type! type: ", combinator.repr

    # echo "selMatch: ", matched, " idx: ", i, "\n"
    combinator = sel.combinator
  
  if matched:
    # echo "matched node: ", node.uid
    # print rule.selectors
    # echo "setting properties:"
    for prop in rule.properties:
      # print rule.properties
      prop.apply(node)

proc applyThemeRules*(node: Figuro) =
  # echo "\n=== Theme: ", node.getId(), " name: ", node.name, " class: ", node.widgetName
  if not node.frame.theme.isNil:
    for rule in node.frame.theme.cssRules:
      rule.eval(node)