import jsffi, math

var
  three* {.importc: "THREE".}: JsObject
  tween* {.importc: "TWEEN".}: JsObject
  flycontrols* {.importc: "FlyControls".}:
    proc (camera: JsObject, container: JsObject): JsObject

var Float32Array* {.importc.}: proc (i: int): JsObject

type Vec3* = distinct JsObject
  ## Lightly wrap the three.js Vector3 type.

proc newVec3*(x, y, z: float): Vec3 = Vec3(jsNew three.Vector3(x, y, z))
proc newVec3*(): Vec3 = newVec3(0.0, 0.0, 0.0)

proc x*(v: Vec3): float = v.js.x.to(float)
proc y*(v: Vec3): float = v.js.y.to(float)
proc z*(v: Vec3): float = v.js.z.to(float)
proc fromVec3*(v: Vec3): Vec3 = newVec3(v.x, v.y, v.z)
proc fromArray*(v: Vec3, j: JsObject) = v.js.fromArray(j)
proc copy*(v1, v2: Vec3) = v1.js.set(v2.x, v2.y, v2.z)
proc `$`*(v: Vec3): string = "(" & $v.x & ", " & $v.y & ", " & $v.z & ")"

# Find intersection point on a sphere surface with radius `r` and center in the
# `b` with a ray [a, b)
proc intersect*(a, b: Vec3, r: float): Vec3 =
  # we are using Cartesian to Spherical coordinates transformation to find
  # theta and phi:
  # https://en.wikipedia.org/wiki/Spherical_coordinate_system#Coordinate_system_conversions
  var
    dx = a.x - b.x
    dy = a.y - b.y
    dz = a.z - b.z
    r1 = math.sqrt(dx * dx + dy * dy + dz * dz)
    theta = math.arccos(dz / r1)
    phi = math.arctan2(dy, dx)

  # And then based on sphere radius we transform back to Cartesian:
  result = newVec3(
    r * math.sin(theta) * math.cos(phi) + b.x,
    r * math.sin(theta) * math.sin(phi) + b.y,
    r * math.cos(theta) + b.z,
  )
