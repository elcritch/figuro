
proc preNode(kind: NodeKind, id: Atom) =
  ## Process the start of the node.

  parent = nodeStack[^1]

  # TODO: maybe a better node differ?
  if parent.nodes.len <= parent.diffIndex:
    # Create Node.
    current = Node()
    current.id = id
    current.uid = newUId()
    parent.nodes.add(current)
    refresh()
  else:
    # Reuse Node.
    current = parent.nodes[parent.diffIndex]
    if resetNodes == 0 and
        current.id == id and
        current.nIndex == parent.diffIndex:
      # Same node.
      discard
    else:
      # Big change.
      current.id = id
      current.nIndex = parent.diffIndex
      current.resetToDefault()
      refresh()

  current.kind = kind
  current.textStyle = parent.textStyle
  current.cursorColor = parent.cursorColor
  current.highlightColor = parent.highlightColor
  current.transparency = parent.transparency
  current.zlevel = parent.zlevel
  current.listens.mouse = {}
  current.listens.gesture = {}
  nodeStack.add(current)
  inc parent.diffIndex

  current.diffIndex = 0
  # when defined(fidgetNodePath):
  current.setNodePath()

  useTheme()