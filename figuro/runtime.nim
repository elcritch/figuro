

import nimscripter, nimscripter/variables

let script = NimScriptFile"""
let required* = "main"
let defaultValueExists* = "foo"
proc fancyStuff*(a: int) = assert a in [10, 300]
"""

addCallable(test3):
  proc fancyStuff(a: int) # Has checks for the nimscript to ensure it's definition doesnt change to something unexpected.

const addins = implNimscriptModule(test3)

let intr = loadScript(script, addins) # This adds in out checks for the proc
intr.invoke(fancyStuff, 10) # Calls `fancyStuff(10)` in vm
intr.invoke(fancyStuff, 300) # Calls `fancyStuff(300)` in vm

getGlobalNimsVars intr:
  required: string # required variable
  optional: Option[string] # optional variable
  defaultValue: int = 1 # optional variable with default value
  defaultValueExists = "bar" # You may omit the type if there is a default value

import unittest
check required == "main"
check optional.isNone
check defaultValue == 1
check defaultValueExists == "foo"
