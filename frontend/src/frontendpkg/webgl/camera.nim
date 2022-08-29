import jsffi, math

import threebind

type Camera* = distinct JsObject
  ## Wrap the three.js PerspectiveCamera.

proc newCamera*(): Camera =
  let
    angle = 75
    aspectRatio = 16.0 / 9.0
      ## The aspectRatio gets updated on resize of the window.
    near = 1
    far = 10000
  result = Camera(jsNew three.PerspectiveCamera(angle, aspectRatio, near, far))
  result.js.position.z = 1000

proc position*(camera: Camera): Vec3 = Vec3(camera.js.position)
proc up*(camera: Camera): Vec3 = Vec3(camera.js.up)
proc fov*(camera: Camera): float = camera.js.fov.to(float)
proc lookAt*(camera: Camera, v: Vec3) = camera.js.lookAt(v.js)

proc flyTo*(camera: Camera, v: Vec3, radius: float) =
  let
    offset = radius / math.tan(math.PI / 180.0 * camera.fov * 0.5)
    target = intersect(camera.position, v, offset)
  camera.lookAt(v)
  camera.position.copy(target)

proc flyTo*(camera: Camera, v: Vec3) =
  camera.flyTo(v, 100.0)

proc autofitNodes*(camera: Camera, geometry: JsObject) =
  geometry.computeBoundingSphere()
  let sphere = geometry.boundingSphere
  camera.flyTo(Vec3(sphere.center), max(sphere.radius.to(float), 100.0))
