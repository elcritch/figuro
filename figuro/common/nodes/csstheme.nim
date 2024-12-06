
import ../../ui/basiccss
import ui
import pretty

template has(val: string): bool =
  val.len() > 0

proc apply*(sel: CssSelector, node: Figuro): bool =
  result = true

  if has(sel.cssType): 
    if node.widgetName == sel.cssType:
      echo "matched type! node: ", $node
    else:
      result = false

  if has(sel.class):
    if sel.class in node.widgetClasses:
      echo "matched class! node: ", $node
    else:
      result = false

proc apply*(rule: CssBlock, node: Figuro) =
  print rule.selectors

  var
    sel: CssSelector
    matched = true

  for i in rule.selectors.len()-1 .. 0:
    sel = rule.selectors[i]
    matched = matched and sel.apply(node)
    echo "selMatch: ", matched, " idx: ", i

proc applyThemeRules*(node: Figuro) =
  echo "\nTheme: ", node.getId(), " name: ", node.name, " class: ", node.widgetName, " theme: ", $node.frame.theme.isNil
  if not node.frame.theme.isNil:
    for rule in node.frame.theme.cssRules:
      rule.apply(node)
