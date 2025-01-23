import std/json
import ../common/nodes/render
import ../common/nodes/transfer
import ../widget
import utils/jsonutils_lite

var
  appWidget* {.compileTime.}: Figuro
  mainApp* {.compileTime.}: proc()
  appTicker* {.compileTime.}: proc()

proc appInit() =
  discard

proc appTick*(val: AppStatePartial): AppStatePartial =
  app.tickCount = val.tickCount
  app.uiScale = val.uiScale
  appTicker()
  result.requestedFrame = app.requestedFrame

# proc appEvent*(ijs: string) =
#   # echo "Event:"
#   uxInputs.fromJson(parseJson(ijs))
#   if root != nil:
#     computeEvents(root)
#   # echo "Input: ", uxInputs.repr

# proc appDraw*(): AppStatePartial =
#   # echo "APP DRAW:"
#   root.diffIndex = 0
#   mainApp()
#   computeScreenBox(nil, root)
#   result.requestedFrame = app.requestedFrame

# proc getRoot*(): seq[Node] =
#   result = root.copyInto()

proc getAppState*(): AppState =
  result = app

proc run*(
    init: proc() {.nimcall.},
    tick: proc(state: AppStatePartial): AppStatePartial {.nimcall.},
    event: proc(inputs: string) {.nimcall.},
    draw: proc(): AppStatePartial {.nimcall.},
    getRoot: proc(): seq[Node] {.nimcall.},
    getAppState: proc(): AppState {.nimcall.},
) =
  discard

proc startFiguro*(frame: var AppFrame) {.forbids: [AppMainThreadEff].} =
  ## Starts Fidget UI library
  ## 

  echo "app: ", frame.repr
  # root = widget
  # appWidget = widget

  # mainApp = proc() =
  #   emit appWidget.onDraw()
  #   # emit appWidget.onHover()
  #   discard

  # appTicker = proc() =
  #   emit appWidget.onTick()

  # setupRoot(appWidget)

  # run(appInit, appTick, appEvent, appDraw, getRoot, getAppState)
