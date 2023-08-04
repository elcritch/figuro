

when defined(js):
  import figura/htmlbackend
  export htmlbackend
elif defined(nullbackend):
  import figura/nullbackend
  export nullbackend
else:
  import engine/openglbackend
  export openglbackend

proc getTitle*(): string =
  ## Gets window title
  windowTitle

proc setTitle*(title: string) =
  ## Sets window title
  if (windowTitle != title):
    windowTitle = title
    setWindowTitle(title)
    refresh()
