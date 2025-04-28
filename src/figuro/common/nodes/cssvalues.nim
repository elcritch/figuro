import std/[strutils, paths, os]
# import ./apis

import pkg/chronicles

import pkg/cssgrid
import pkg/cssgrid/gridtypes
import pkg/cssgrid/variables

import basics
import cssbasics

export gridtypes

type
  CssValues* = ref object of CssVariables
    applied*: HashSet[Atom]
    parent*: CssValues
    values*: Table[CssVarId, CssValue]

proc newCssValues*(): CssValues =
  result = CssValues(applied: initHashSet[Atom]())

proc newCssValues*(parent: CssValues): CssValues =
  result = CssValues(applied: parent.applied, parent: parent)

proc setVariable*(vars: CssValues, idx: CssVarId, value: CssValue) =
  let isSize = value.kind == CssValueKind.CssSize
  vars.values[idx] = value
  if isSize:
    variables.setVariable(vars, idx, value.cx.value)

proc setFunction*(vars: CssValues, idx: CssVarId, fun: CssFunc) =
  variables.setFunction(CssVariables(vars), idx, fun)

proc setDefault*(vars: CssValues, idx: CssVarId, value: CssValue) =
  if idx notin vars.values:
    vars.setVariable(idx, value)

proc `$`*(vars: CssValues): string =
  ## Returns a string representation of the CSS variables
  result = "CssValues:\n"
  # Add names table
  result.add "  Names:\n"
  for name, id in vars.names:
    result.add "    " & $name & " => " & $id & "\n"
  
  # Add variables table
  result.add "  Variables:\n"
  for id, value in vars.variables:
    let varName = vars.variableName(id)
    let nameStr = if varName != "": " (" & varName & ")" else: ""
    result.add "    " & $id & nameStr & " => " & $value & "\n"

  # Add values table
  result.add "  Values:\n"
  for id, value in vars.values:
    let varName = vars.variableName(id)
    let nameStr = if varName != "": " (" & varName & ")" else: ""
    result.add "    " & $id & nameStr & " => " & $value & "\n"
  
  # Add functions table
  result.add "  Functions:\n"
  for id, _ in vars.funcs:
    let varName = vars.variableName(id)
    let nameStr = if varName != "": " (" & varName & ")" else: ""
    result.add "    " & $id & nameStr & " => <function>\n"

proc registerVariable*(vars: CssValues, name: Atom): CssVarId =
  ## Registers a new CSS variable with the given name
  ## Returns the variable index
  var v = vars
  while v != nil:
    if name in v.names:
      return v.names[name]
    v = v.parent
  result = variables.registerVariable(vars, name)

proc registerVariable*(vars: CssValues, name: static string): CssVarId =
  result = vars.registerVariable(atom(name))

proc registerVariable*(vars: CssValues, name: static string, default: CssValue): CssVarId =
  let name = atom(name)
  result = vars.registerVariable(name)
  vars.setDefault(result, default)

proc registerVariable*(vars: CssValues, name: static string, default: ConstraintSize): CssVarId =
  let name = atom(name)
  result = vars.registerVariable(name)
  vars.setDefault(result, default)

proc resolveVariable*(vars: CssValues, varIdx: CssVarId, val: var ConstraintSize): bool =
  if vars.resolveVariable(varIdx, val):
    result = true
  elif vars.parent != nil:
    result = vars.parent.resolveVariable(varIdx, val)

proc lookupVariable(vars: CssValues, varIdx: CssVarId, val: var CssValue, recursive: bool = true): bool =
  if vars != nil and varIdx in vars.values:
    val = vars.values[varIdx]
    return true
  elif vars.parent != nil and recursive:
    result = vars.parent.lookupVariable(varIdx, val, recursive)

proc lookupVariable(vars: CssValues, varName: static string, val: var CssValue, recursive: bool = true): bool =
  let varName = atom(varName)
  if vars != nil and varName in vars.names:
    val = vars.values[vars.names[varName]]
    return true
  elif vars.parent != nil and recursive:
    result = vars.parent.lookupVariable(varName, val, recursive)

proc resolveVariable*(vars: CssValues, varIdx: CssVarId, val: var CssValue): bool =
  ## Resolves a constraint size, looking up variables if needed
  var res: CssValue
  if vars != nil and lookupVariable(vars, varIdx, res, recursive = true):
    # Handle recursive variable resolution (up to a limit to prevent cycles)
    var resolveCount = 0
    while res.kind == CssValueKind.CssVarName and resolveCount < 10:
      if lookupVariable(vars, res.id, res, recursive = false):
        inc resolveCount
      else:
        break
    if res.kind == CssValueKind.CssVarName: # Prevent infinite recursion, return a default value
      val = MissingCssValue()
      return false
    else:
      val = res
      return true
  else:
    return false

