
import common

proc getTitle*(): string =
  ## Gets window title
  windowTitle

proc setTitle*(title: string) =
  ## Sets window title
  if (windowTitle != title):
    windowTitle = title
    setWindowTitle(title)
    refresh()
