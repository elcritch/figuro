
import ../../ui/basiccss
import ui

proc applyThemes*(node: Figuro) =
  echo "Theme: ", node.getId(), " name: ", node.name, " class: ", node.widgetName, " theme: ", $node.frame.theme.isNil
  discard
