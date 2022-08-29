## Provide an example to prove that the renderer is working.
import jsffi
import math
import times

import threebind

type
  ExampleCube* = object
    cube*: JsObject

proc newExampleCube*(scene: JsObject): ExampleCube =
  result = ExampleCube()
  let
    geometry = jsNew three.BoxGeometry(10, 10, 10)
    material = jsNew three.MeshBasicMaterial(js{"color": 0x000000})
  result.cube = jsNew three.Mesh(geometry, material)
  scene.add(result.cube)

proc update*(ex: var ExampleCube) =
  ex.cube.rotation.x += toJs(0.01)
  ex.cube.rotation.y += toJs(0.01)
  let time = epochTime()
  ex.cube.position.x = cos(time) * 50
  ex.cube.position.y = sin(time) * cos(time) * 50
  ex.cube.position.z = sin(time) * 50
