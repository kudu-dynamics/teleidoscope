import karax / [jwebsockets, karax]

type
  UIStateType* {.pure.} = enum
    FirstLoad,
    ChooseGraph,
    LoadingGraph,
    GraphVisualization,

## State Variables that drive the UI
## =================================
## Changes to these variables will generally trigger a redraw.
var
  UIState*: UIStateType = UIStateType.FirstLoad

  ForeignCount*: int = 0
    ## Provide an incrementing counter for any elements that we should
    ## keep out of karax's control.

  SelectedGraph*: string = ""

  GraphSocket*: WebSocket = nil

proc showChooseGraphUI*() =
  UIState = UIStateType.ChooseGraph
  redrawSync()

proc showLoadingGraph*(graph: string) =
  UIState = UIStateType.LoadingGraph
  SelectedGraph = graph
  redrawSync()

proc showGraphVisualization*() =
  # DEV: This state transition seems to require a manual
  #      synchronization. Unsure as to why.
  UIState = UIStateType.GraphVisualization
  redrawSync()
