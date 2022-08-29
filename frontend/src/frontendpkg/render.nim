## render.nim
##
## This module takes `ngraph.pixel <https://github.com/anvaka/ngraph.pixel>`_
## and makes a few modifications in pure Nim.
##
## DEV: The layout returns a Vector3d object which is slightly different from
##      the Vector3 object type that we coerce into Vec3s.
import dom, jsffi, sequtils, strformat, strutils, sugar

import gradient, focus, storm, view

import webgl / [camera, geomap, proxy, threebind]

proc createLayout(graph: JsObject): JsObject =
  var physicsOptions = js{
    "integrator": "verlet",
    "springLength": 100,
    "springCoeff": 0.0008,
    "gravity": -0.6,
    "theta": 0.8,
    "dragCoeff": 0.02,
    "timeStep": 20,
  }
  var factory {.importc: "layout".}: proc (graph, options: JsObject): JsObject
  result = factory(graph, physicsOptions)

proc cluster(graph: JsObject): JsObject {.importc: "createWhisper".}

type
  RenderEngine* = ref RenderEngineObj
  RenderEngineObj = object
    renderer: JsObject
      ## three.js WebGL renderer
    container*: Node
      ## The created canvas node
    scene0: JsObject
      ## three.js scene
    scene1: JsObject
      ## three.js scene
    camera: Camera
      ## Perspective Camera
    layout: JsObject
      ## Layout algorithm
    whisper: JsObject
      ## Clustering by Chinese Whisper

    # Camera Controllers.
    flycontrols: JsObject
      ## three.js FlyControls
    orbitcontrols: JsObject
      ## three.js OrbitControls

    # Variables concerning the state of the engine.
    is_dark_mode*: bool
      ## Whether or not the background is dark or not.
    is_layout_stable: bool
      ## Whether or not the layout should be consulted for node positions.
    is_focus_stable: bool
      ## Whether or not the camera focus has shifted.
    focus_option: FocusOption
      ## The target to focus.

    # Renderable child constructs of the engine.
    gproxy: GraphProxy

proc resize*(engine: RenderEngine) =
  let boundingRect = engine.container.getBoundingClientRect()
  engine.camera.toJs().aspect = boundingRect.width / boundingRect.height
  engine.camera.toJs().updateProjectionMatrix()
  engine.renderer.setSize(boundingRect.width, boundingRect.height)

proc attach*(target_container: Node, graph: JsObject): RenderEngine =
  result.new()
  result.renderer = jsNew three.WebGLRenderer(
    js{"alpha": true, "antialias": true}
  )
  result.renderer.autoClear = false
  result.renderer.vr = true
  # White and Opaque.
  result.renderer.setClearColor(0xFFFFFF, 0)
  result.renderer.setPixelRatio(window.devicePixelRatio)
  result.container = target_container
  result.scene0 = jsNew three.Scene()
  result.scene1 = jsNew three.Scene()
  result.camera = newCamera()
  result.layout = createLayout(graph)
  result.is_dark_mode = false
  result.is_layout_stable = false
  result.is_focus_stable = false

  # Add the container to the DOM.
  # Set tabindex so that the canvas becomes focusable.
  let node = result.renderer.domElement.to(Node)
  node.toJs().setAttribute("tabindex", "1")
  node.toJs().focus()
  result.container.appendChild(node)
  result.resize()

  # Add the camera controllers.
  result.flycontrols = flycontrols(result.camera.js, node.toJs)
  result.orbitcontrols = jsNew three.OrbitControls(result.camera.js, node.toJs)
  result.orbitcontrols.enableKeys = false
  result.orbitcontrols.enablePan = false

  # Add the renderable objects.
  result.gproxy = newGraphProxy(result.scene0, result.scene1, graph)

  # Update the renderable graph when the graph changes.
  graph.on("changed") do (changes: JsObject):
    for change in changes:
      let change_type = $change.changeType.to(cstring)
      if change_type in ["add", "update"] and change.node != jsUndefined:
        result.gproxy.addNode(change.node)
      elif change_type in ["add", "update"] and change.link != jsUndefined:
        result.gproxy.addEdge($change.link.fromId.to(cstring),
                              $change.link.toId.to(cstring))
      else:
        continue
      result.is_layout_stable = false

  return result

proc render(engine: RenderEngine) =
  # Render 2 scenes. The first contains the edges and the second contains the
  # nodes.
  #
  # https://stackoverflow.com/questions/12666570/how-to-change-the-zorder-of-object-with-threejs/12666937#12666937
  engine.renderer.clear()
  engine.renderer.render(engine.scene0, engine.camera)
  engine.renderer.clearDepth()
  engine.renderer.render(engine.scene1, engine.camera)

proc update_layout(engine: RenderEngine) =
  if engine.is_layout_stable:
    return
  engine.is_layout_stable = engine.layout.step().to(bool)

  for id in engine.gproxy.edges.keys:
    engine.gproxy.updateEdgePosition(
      id,
      Vec3(engine.layout.getNodePosition(id.a)),
      Vec3(engine.layout.getNodePosition(id.b)),
    )
  for id in engine.gproxy.nodes.keys:
    engine.gproxy.updateNodePosition(
      id,
      Vec3(engine.layout.getNodePosition(id)),
    )

proc update_cluster(engine: RenderEngine) =
  if engine.whisper.isNull() or engine.whisper.isUndefined():
    return

  const requiredChangeRate = 0
  let rate = engine.whisper.getChangeRate().to(int)
  if rate > requiredChangeRate:
    engine.whisper.step()
  else:
    # Upon completion, set the colors.
    for node_id in engine.gproxy.nodes.keys():
      let
        class: int = engine.whisper.getClass(node_id).to(int)
        color = toSeq(defaultGradient(class, class + 1))[0]
        color_r = float((color shr 16) and 0xFF)
        color_g = float((color shr 8) and 0xFF)
        color_b = float((color and 0xFF))
      engine.gproxy.nodes.set("color", node_id, color_r, color_g, color_b)

proc update_focus(engine: RenderEngine) =
  if engine.is_focus_stable:
    return
  engine.is_focus_stable = true

  # Retire the current focus option.
  case engine.focus_option.last:
    of Free:
      engine.flycontrols.dispose()
      engine.orbitcontrols.enabled = true
    else:
      discard
  # Activate the new focus option.
  case engine.focus_option.kind:
    of Graph:
      engine.focus_option.max = engine.gproxy.nodes.len
    of Free:
      # DEV: Apparently `reset` is a reserved word that causes side effects.
      engine.flycontrols.clearState()
      engine.flycontrols.activate()
      engine.orbitcontrols.enabled = false
    else:
      discard

  var content = ""
  case engine.focus_option.kind:
    of Autofit:
      content &= """
instructions
left     - switch to last mode
right    - switch to next mode
esc      - free flight mode
space    - pause/play active layout computation
h        - hide overlays
c        - enable/disable community detection
dblclick - zoom to node
"""
    of Free:
      content &= """
free flight
wasd  - forward/left/back/right
qe    - roll left/right
rf    - up/down
shift - hold to increase speed
"""
    of Graph:
      let
        focus_id = engine.gproxy.getId(engine.focus_option.i)
        maybeSnode = engine.gproxy.getNode(focus_id)

      content &= fmt"""
node - [{engine.focus_option.i + 1} / {engine.gproxy.nodes.len}]
"""
      if maybeSnode.isSome:
        let snode = maybeSnode.get()
        content &= fmt"""
form - {snode.ndef.form}
valu - {snode.ndef.valu}
"""
        for tag in snode.info.tags:
          content &= fmt"#{tag}"
          content &= "\n"

  updateGraphInfoComponent(content)

proc toggle_dark_mode(engine: RenderEngine) =
  engine.is_dark_mode = not engine.is_dark_mode

  # Set the renderer background color.
  if engine.is_dark_mode:
    engine.renderer.setClearColor(0x000000, 1)
  else:
    engine.renderer.setClearColor(0xFFFFFF, 0)

  # Set the default color of the edges.
  for edge_id in engine.gproxy.edges.keys():
    if engine.is_dark_mode:
      engine.gproxy.edges.set("color", edge_id, 0xFF, 0xFF, 0xFF)
    else:
      engine.gproxy.edges.set("color", edge_id, 0x00, 0x00, 0x00)

proc update_camera(engine: RenderEngine) =
  case engine.focus_option.kind:
    of Autofit:
      engine.camera.autofitNodes(engine.gproxy.nodes.geometry)
    of Free:
      engine.flycontrols.update(2)
    of Graph:
      if not engine.focus_option.stable:
        let
          focus_idx = engine.focus_option.i
          focus_id = engine.gproxy.getId(focus_idx)
          target_pos = Vec3(engine.layout.getNodePosition(focus_id)).fromVec3()
        engine.focus_option.stable = true
        engine.camera.flyTo(target_pos)
        engine.orbitcontrols.target = target_pos
  # OrbitControls interfere with flight.
  if engine.focus_option.kind != Free:
    engine.orbitcontrols.update()

proc search*(engine: RenderEngine, value: string) =
  # Get the starting index (0 or current node).
  var start_idx =
    if engine.focus_option.kind == Graph:
       (engine.focus_option.i + 1) mod engine.gproxy.nodes.len()
     else:
       0
  # Allow search to wrap-around.
  # XXX: Expensive per the number of keys.
  let keys = toSeq(engine.gproxy.nodes.keys())
  for node_id in concat(keys[start_idx..^1], keys[0..(start_idx)]):
    let maybeSnode = engine.gproxy.getNode(node_id)
    if maybeSnode.isSome:
      let snode = maybeSnode.get()
      var found = false
      # Search for any matching forms.
      if snode.ndef.form == value:
        found = true
      # Search for any matching values.
      elif snode.ndef.valu in [value, &"\"{value}\""]:
        found = true
      # Search for any matching tags.
      elif toSeq(snode.info.tags).any(pattern => pattern.contains(value)):
        found = true
      if found:
        let node_idx = engine.gproxy.getIdx(node_id)
        engine.is_focus_stable = false
        engine.focus_option.point(node_idx)
        break

proc run*(engine: RenderEngine) =
  let canvas = engine.container.toJs.children[2]
  canvas.addEventListener("keydown") do (ev: JsObject):
    let code = $ev.code.to(cstring)
    case code:
      of "ArrowLeft", "ArrowRight", "Escape":
        # Cycle through focus options.
        case code:
          of "ArrowLeft": engine.focus_option = engine.focus_option - 1
          of "ArrowRight": engine.focus_option = engine.focus_option + 1
          of "Escape": engine.focus_option = engine.focus_option * Free
        engine.is_focus_stable = false
      of "Space":
        engine.is_layout_stable = not engine.is_layout_stable
      of "KeyH":
        # Hide the graph overlays.
        let elements = document.getElementsByClassName("graph-overlay")
        for element in elements:
          let hidden = element.getAttribute("hidden")
          if hidden.isNil:
            element.setAttribute("hidden", "")
          else:
            element.removeAttribute("hidden")
      of "KeyC":
        # Make a human determination as to when a new whisper should be made.
        if engine.whisper.isNull() or engine.whisper.isUndefined():
          engine.whisper = cluster(engine.gproxy.graph)
        else:
          engine.whisper = nil
      of "KeyL":
        engine.toggle_dark_mode()
      else:
        discard

  var
    raycaster = jsNew three.Raycaster()
    mouse = jsNew three.Vector2()
  raycaster.params.Points.threshold = 5

  canvas.addEventListener("dblclick") do (ev: JsObject):
    ev.preventDefault()
    ev.stopPropagation()

    let
      boundingRect = engine.container.getBoundingClientRect()
      normX = ev.pageX.to(float) - boundingRect.left
      normY = ev.pageY.to(float) - boundingRect.top
    mouse.x = (normX / boundingRect.width) * 2 - 1
    mouse.y = -(normY / boundingRect.height) * 2 + 1

    raycaster.setFromCamera(mouse, engine.camera.js)
    var intersects = raycaster.intersectObjects(engine.scene1.children)
    for intersect in intersects:
      if $intersect["object"].name.to(cstring) != "nodes":
        continue
      engine.focus_option = FocusOption(
        kind: Graph,
        last: engine.focus_option.kind,
        max: engine.gproxy.nodes.len,
      )
      let idx = intersect.index.to(int)
      engine.focus_option.point(min(engine.gproxy.nodes.len - 1, idx))
      engine.is_focus_stable = false

  engine.renderer.setAnimationLoop do:
    # Update the graph layout.
    engine.update_layout()
    # Update the graph cluster.
    engine.update_cluster()
    # Update the interface focus.
    engine.update_focus()
    # Update the camera.
    engine.update_camera()
    # Render the scene.
    tween.update()
    engine.render()
