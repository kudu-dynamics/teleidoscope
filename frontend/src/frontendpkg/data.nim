import base64, dom, jsffi, options, strformat, uri
import karax / [jwebsockets, kajax]

import state, storm

## Graph
## =====
var
  createGraph {.importc: "createGraph".}: proc (): JsObject
  graph*: JsObject = createGraph()
    ## The ngraph.graph graph object.


## Loading data from the Backend
## =============================
proc apiurl(protocol: cstring = window.location.protocol): string =
  &"{protocol}//{window.location.host}"


proc checkGraph*(data: JsObject) =
  proc checkGraphCB(status: int, response: cstring) =
    if status == 200:
      showLoadingGraph($data["path"].to(cstring))
    else:
      echo response

  ajaxPost(
    &"{apiurl()}/v1/graphs",
    @[],
    data.toJson(),
    checkGraphCB,
    doRedraw = false,
  )

proc loadGraph*() =
  let wsprotocol =
    if window.location.protocol == "https:":
      "wss:"
    else:
      "ws:"

  let
    b64EncodedPath = base64.encode(SelectedGraph)
    uriEncodedPath = uri.encodeUrl(b64EncodedPath)
  GraphSocket = newWebSocket(
    &"{apiurl(wsprotocol)}/v1/graphs/{uriEncodedPath}/ws"
  )

  proc openGraphData(e: MessageEvent) =
    showGraphVisualization()

  proc recvGraphData(e: MessageEvent) =
    let data = fromJson[JSObject](e.data)

    case $data["type"].to(cstring):
    of "node":
      # Validate that a node is being received.
      let new_snode: StormNode = StormNode(data["node"])
      let exist_snode_wrapper: JsObject = graph.getNode(new_snode.iden)
      if (not exist_snode_wrapper.isNull() and
          not exist_snode_wrapper.isUndefined() and
          exist_snode_wrapper.data.is_storm_node()):
        # DEV: If the node already exists, we need to merge them.
        let
          exist_snode = StormNode(exist_snode_wrapper.data)
          merged_snode = merge(exist_snode, new_snode)
        if not (merged_snode.isNull() or merged_snode.isUndefined()):
          graph.addNode(new_snode.iden, merged_snode)
      else:
        # DEV: Add a brand new node.
        graph.addNode(new_snode.iden, new_snode)
    of "edge":
      let
        snode1: StormNode = StormNode(data["node1"])
        snode2: StormNode = StormNode(data["node2"])
      graph.addLink(snode1.iden, snode2.iden)

  GraphSocket.onmessage = recvGraphData
  GraphSocket.onopen = openGraphData
