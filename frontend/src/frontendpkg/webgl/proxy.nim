## proxy.nim
##
## Define the proxy objects for mapping nodes to their low-level WebGL render
## objects
import jsffi, options, sequtils, strutils, tables

import .. / storm
import geomap, shader, threebind

let
  defaultNodeCount = 100000
  defaultEdgeCount = defaultNodeCount

type
  EdgeKey* = tuple[a, b: string]
    ## Use a pair of node ids to map to an edge.
  GraphProxy* = object
    graph*: JsObject
    nodes*: GeoMap[string]
    edges*: GeoMap[EdgeKey]

proc newGraphProxy*(scene0, scene1, graph: JsObject): GraphProxy =
  result = GraphProxy()
  result.graph = graph
  # Add edges to a scene that gets rendered before the nodes scene.
  result.edges = newGeoMap[EdgeKey]()
  result.edges.attribute("position", defaultEdgeCount * 2, 3)
  result.edges.attribute("color", defaultEdgeCount * 2, 3)
  let edgesMesh = makeMesh(result.edges.geometry, "edges")
  scene0.add(edgesMesh)
  result.nodes = newGeoMap[string]()
  result.nodes.attribute("position", defaultNodeCount, 3)
  result.nodes.attribute("color", defaultNodeCount, 3)
  result.nodes.attribute("size", defaultNodeCount, 1)
  let nodesMesh = makeMesh(result.nodes.geometry, "nodes")
  scene1.add(nodesMesh)

proc updateNodePosition*(proxy: var GraphProxy, id: string, p: Vec3) =
  proxy.nodes.set("position", id, p.x, p.y, p.z)

proc updateEdgePosition*(proxy: var GraphProxy, id: EdgeKey, p1, p2: Vec3) =
  proxy.edges.set("position", id, p1.x, p1.y, p1.z, p2.x, p2.y, p2.z)

proc getNode*(proxy: GraphProxy, id: string): Option[StormNode] =
  let node = proxy.graph.getNode(id).data
  if node.is_storm_node():
    some(node.StormNode)
  else:
    none(StormNode)

proc getId*(proxy: GraphProxy, idx: int): string =
  # XXX: Do lazy, not a full lift.
  toSeq(proxy.nodes.keys())[idx]

proc getIdx*(proxy: GraphProxy, id: string): int =
  # XXX: Do lazy, not a full lift.
  toSeq(proxy.nodes.keys()).find(id)

proc addNode*(proxy: var GraphProxy, node: JsObject) =
  let
    id = $node.id.to(cstring)
    style = style(StormNode(node.data))
    color_r = float((style.color shr 16) and 0xFF)
    color_g = float((style.color shr 8) and 0xFF)
    color_b = float(style.color and 0xFF)
    size = float(style.size)
  proxy.nodes.set("color", id, color_r, color_g, color_b)
  proxy.nodes.set("size", id, size)

proc addEdge*(proxy: var GraphProxy, id1, id2: string) =
  # Create an edge index.
  let
    comparison = cmpIgnoreCase(id1, id2)
    ekey = if comparison < 0:
             (a: id1, b: id2)
           else:
             (a: id2, b: id1)
  discard proxy.edges.getIdx(ekey, skip = 2)
