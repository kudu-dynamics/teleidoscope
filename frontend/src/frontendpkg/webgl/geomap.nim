import jsffi, tables

import threebind

type
  GeoMap*[K] = object
    geometry*: JsObject
      ## WebGL BufferGeometry object.
    idMap: OrderedTable[K, int]
      ## A map from a key type K to the corresponding array index.
    attrMap: Table[string, int]
      ## A map from attribute name to corresponding attribute array dimensions.

proc newGeoMap*[K](): GeoMap[K] =
  result = GeoMap[K]()
  result.geometry = jsNew three.BufferGeometry()
  result.geometry.dynamic = true
  result.idMap = initOrderedTable[K, int]()
  result.attrMap = initTable[string, int]()

proc len*[K](gm: GeoMap[K]): int = gm.idMap.len

iterator keys*[K](gm: GeoMap[K]): K =
  for key in gm.idMap.keys:
    yield key

proc attribute*[K](gm: var GeoMap[K], name: string, count, dimensions: int) =
  gm.geometry.addAttribute(
    name,
    jsNew three.BufferAttribute(
      jsNew Float32Array(count * dimensions), dimensions
    ),
  )
  gm.geometry.getAttribute(name).setDynamic(true)
  gm.attrMap[name] = dimensions

proc getIdx*[K](gm: var GeoMap[K], id: K, skip: int = 1): int =
  if id notin gm.idMap:
    # XXX: Address this in the future for handling deletions.
    gm.idMap[id] = gm.idMap.len * skip
  return gm.idMap[id]

iterator get*[K](gm: GeoMap[K], name: string, id: K): tuple[i: int, v: float] =
  let
    attr = gm.geometry.getAttribute(name)
    dimensions: int = gm.attrMap[name]
    idx: int = gm.getIdx(id)
  for i in 0 ..< dimensions:
    yield (i: i, v: attr["array"][idx * dimensions * i])

proc set*[K](gm: var GeoMap[K], name: string, id: K, values: varargs[float | int]) =
  let
    attr = gm.geometry.getAttribute(name)
    dimensions: int = gm.attrMap[name]
    idx: int = gm.getIdx(id)
  for i, v in values:
    attr["array"][idx * dimensions + i] = v
  attr.needsUpdate = true
