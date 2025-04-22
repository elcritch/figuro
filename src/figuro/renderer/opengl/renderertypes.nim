import std/[times, locks]
import pkg/threading/atomics

import glcommons, context, formatflippy, utils

import ../../common/rchannels
import ../../common/nodes/uinodes

type Renderer*[W] = ref object
  ctx*: Context
  duration*: Duration
  window*: W
  uxInputList*: RChan[AppInputs]
  rendInputList*: RChan[RenderCommands]
  frame*: WeakRef[AppFrame]
  lock*: Lock
  updated*: Atomic[bool]

  nodes*: Renders
  appWindow*: AppWindow