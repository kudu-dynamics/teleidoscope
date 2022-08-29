import dom, jsffi
include karax / prelude

# Importing globals first, means that the JavaScript library bindings are made
# available early to the other modules.
import frontendpkg / globals

# The order of these includes are important.
import frontendpkg / [data, render, state, view]

template hookFormSubmit(formNode: dom.Node, hook: untyped) =
  formNode.addEventListener("submit") do (ev: dom.Event):
    ev.preventDefault()
    # DEV: An assumption is being made that there is exactly 1 input element
    #      in the hooked form.
    for elem in Element(ev.target).getElementsByTagName("input"):
      var jelem = toJs(elem)
      hook(jelem["value"].to(cstring))
      jelem.value = ""

## Main Routine after DOM construction
## ===================================
view do (data: any):
  case UIState:

  of UIStateType.FirstLoad:
    # XXX: Artificially stage a short load time.
    discard setTimeout(nil, 200)
    showChooseGraphUI()

  of UIStateType.ChooseGraph:
    getChooseGraphViewForm().hookFormSubmit do (value: cstring):
      checkGraph(js{"path": value})

  of UIStateType.LoadingGraph:
    loadGraph()

  of UIStateType.GraphVisualization:
    ## Renderer
    ## ========
    let engine = render.attach(getGraphCanvasView(), graph)
    window.addEventListener("resize") do (evt: dom.Event): engine.resize()

    # # Set the graph search form action.
    getGraphSearchComponentForm().hookFormSubmit do (value: cstring):
      # XXX: Indicate by search bar's border color if a search is successful.
      engine.search($value)

    engine.run()
