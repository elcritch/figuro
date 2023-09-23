
import ../../figuro
import ../widget

export figuro
export widget

type
  StatefulFiguro*[T] = ref object of Figuro
    state*: T
