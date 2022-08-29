## focus.nim
##
## Manage the selection, filtering, and focus of the camera.
import math, options
export options

type
  FocusType* = enum Autofit, Free, Graph
    ## The types of focus that can be applied, Graph must come last.

  FocusOption* = object
    case kind*: FocusType
    of Graph:
      i*, max*: int
      stable*: bool
    else: discard
    last*: FocusType

# const extra_opt_count: int = ord(FocusType.high)
## The extra options that can be focused before the graph.

var loaded: bool = false

proc point*(option: var FocusOption, i: int) =
  case option.kind:
    of Graph:
      discard
    else:
      option.last = option.kind

  option.kind = Graph
  option.stable = option.i == i
  option.i = i

proc `+`*(option: var FocusOption, delta: int): FocusOption =
  var change: bool = false
    ## Whether or not we need to change to a different FocusOption.
  case option.kind:
    of Graph:
      # Switch nodes within the graph.
      # If a change is made outside the range of the graph,
      # switch to the next focus option.
      option.point(option.i + delta)
      change = option.i < 0 or option.i >= option.max
    else:
      change = delta != 0
  if not change:
    option.last = option.kind
    return option

  loaded = true

  # floorMod works the same way as Python's mod operator.
  # -1 mod 10 = -1
  # floorMod(-1, 10) = 9
  let nkind = floorMod(ord(option.kind) + delta, ord(FocusType.high) + 1)
  FocusOption(
    kind: FocusType(nkind),
    last: option.kind,
  )

proc `-`*(option: var FocusOption, delta: int): FocusOption = option + (-delta)

proc `*`*(option: FocusOption, change: FocusType): FocusOption =
  FocusOption(kind: change, last: option.kind)
