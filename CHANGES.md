- TODO:
  + add auto-fill for child-based resizing with grid
  + fix align/justify center in Horizontal/Vertical
  + add minimum button click time (?)
- Release `v0.12.2`
  + port over to dom monitor
- Release `v0.12.0`
  + switched to using `this` instead of `node` for the implicit variable
  + refactor Text and Input widget apis
  + add new text apis font myFont, justify Left, align Top
  + added textChanged apis for check if not this.textChanged(""): setDefaultText()
- Release `v0.11.0`
  + add alternative as syntax for new widgets, e.g. Button[int] as "plusBtn"
  + fix textbox's box not being updated from the UI nodes
  + fix hAlign and vAlign argument plumbing for Input and Textboxes
  + add helpers in Input for setting font color, vertical/horiz alignments
  + add inline vertical and horizontal layout helpers
  + update binding using Sigils new Sigil[T] reactive type
- Release `v0.10.0`
  + changed EventKind to Init, Exit, and Done and changed doClick
- Release `v0.9.1`
  + fixed setTitle
