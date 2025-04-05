
import ../widget
import ../ui/animations

type
  Slider*[T] = ref object of StatefulFiguro[T]
    label*: string
    min*, max*: T
    dragStart*: Option[Position]

proc draw*[T](self: Slider[T]) {.slot.} =
  ## slider widget
  withWidget(self):

    gridCols 10'ux ["left"] 1'fr ["right"] 10'ux
    gridRows 10'ux ["top"] 1'fr ["bottom"] 10'ux

    WidgetContents()

    if self.label.len() > 0:
      Text.new "text":
        gridArea 2 // 3, 2 // 3
        text {defaultFont(): self.label}

    Rectangle.new "barFgTexture":
      gridArea 2 // 3, 2 // 3
      clipContent true

    Rectangle.new "bar":
      gridArea 2 // 3, 2 // 3
      let sliderWidth = csPerc(100 * self.state.float.clamp(self.min.float, self.max.float))
      let sliderSize = 20

      Rectangle.new "filling":
        # Draw the bar itself.
        fill css"#2B9FEA"
        size sliderWidth, 100'pp

      Rectangle.new "button":
        fill css"black" * 0.3
        size ux(sliderSize), ux(sliderSize)
        # useTheme atom"active"
        # useTheme atom"pop"

        # let sliderPos = self.dragger.position(props.value)
        # if sliderPos.updated:
        #   dispatchEvent changed(self.dragger.value)
      
        offset sliderWidth-ux(sliderSize/2), 0'ux

    # Rectangle.new "bar-gloss":
    #   gridArea 1 // 4, 1 // 4
    #   border 2, css"black"
    #   fill css"blue"

