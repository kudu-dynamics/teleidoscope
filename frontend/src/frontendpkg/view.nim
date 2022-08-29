## view.nim
##
## Define a component-style approach to the UI.
import dom, strformat, strutils

include karax / prelude
import karax / [vstyles]

import state

## Helper Components

proc foreign(kfid: cstring = nil): cstring =
  if kfid.isNil:
    result = &"kfid_{ForeignCount}"
  else:
    result = kfid
  ForeignCount += 1
  setForeignNodeId(result)

proc loader(text: string): VNode =
  buildHtml:
    tdiv(class="pageloader is-active"):
      span(class="title no-select"):
        text text

proc icon(class: string,
          margin_left: string = "0rem",
          margin_right: string = "0rem"): VNode =
  buildHtml:
    italic(class=class,
           style=style(
             (StyleAttr.marginLeft, kstring(margin_left)),
             (StyleAttr.marginRight, kstring(margin_right)),
           )):
      discard

proc hero(title: string,
          is_fullheight: bool = false): VNode =
  var hero_class = "hero is-primary"
  if is_fullheight:
    hero_class &= " is-fullheight"
  buildHtml(tdiv(class=hero_class)):
    tdiv(class="hero-body has-text-centered"):
      tdiv(class="container"):
        h1(class="title no-select",
           id=foreign(),
           style=style(
             (StyleAttr.fontSize, kstring"4rem"),
           )):
          icon("fa fa-microscope is-large", margin_right = "1rem")
          text title

## Main Components

let
  chooseGraphFormId = "choose-graph-form"
  graphInfoDivId    = "graph-info-div"
  graphSearchFormId = "graph-search-form"

proc chooseGraphView(): VNode =
  # This view is a minimalist page that contains a search bar to look up a graph
  # to load for visualization.
  buildHtml(tdiv):
    hero("Teleidoscope")

    section(class="section"):
      tdiv(class="container field",
           style=style(
             (StyleAttr.paddingTop, kstring"3rem"),
           )):
        p(class="control has-icons-left"):
          form(id=foreign(chooseGraphFormId)):
            input(class="input is-large is-rounded",
                  placeholder="s3://bucket/object",
                  `type`="text")
            span(class="icon is-large is-left"):
              icon("fas fa-search",
                   margin_left = "1rem",
                   margin_right = "1rem")

proc getChooseGraphViewForm*(): dom.Node =
  dom.document.getElementById(chooseGraphFormId)

proc graphInfoComponent(): VNode =
  # This component is a basic box to hold information about the rendered graph.
  buildHtml:
    tdiv(class="graph-info graph-overlay",
         id=graphInfoDivId):
      discard

proc getGraphInfoComponent*(): dom.Node =
  ## NOTE: This needs to be called post render.
  dom.document.getElementsByClassName("graph-info")[0]

proc updateGraphInfoComponent*(content: var string) =
  content.removeSuffix('\n')
  getGraphInfoComponent().innerHTML = content

proc graphSearchComponent(): VNode =
  # This component is a search bar to search the rendered graph for nodes.
  buildHtml:
    tdiv(class="graph-search graph-overlay"):
      form(id=graphSearchFormId):
        input(placeholder="enter a search term", `type`="text")

proc getGraphSearchComponentForm*(): dom.Node =
  dom.document.getElementById(graphSearchFormId)

proc graphCanvasView(): VNode =
  # This view
  buildHtml:
    section(class="hero is-fullheight"):
      tdiv(class="hero-body graph-container is-marginless is-paddingless"):
        graphInfoComponent()
        graphSearchComponent()

proc getGraphCanvasView*(): dom.Node =
  ## NOTE: This needs to be called post render.
  dom.document.getElementsByClassName("graph-container")[0]

proc createDom(data: RouterData): VNode =
  ## Based on the UIState, the rendering of the page is going to be different.
  buildHtml:
    case UIState:

    of UIStateType.FirstLoad:
      loader("Teleidoscope")

    of UIStateType.ChooseGraph:
      # This page shows a header and a single search bar below for the user to
      # provide an AWS S3 URI (e.g. s3://bucket/path) to an archive to load.
      chooseGraphView()

    of UIStateType.LoadingGraph:
      loader("Loading Graph")

    of UIStateType.GraphVisualization:
      # The Graph Canvas View contains the three.js renderer used for
      # visualization.
      graphCanvasView()

proc view*(callback: proc (data: RouterData)) =
  setRenderer(renderer = createDom, clientPostRenderCallback = callback)
