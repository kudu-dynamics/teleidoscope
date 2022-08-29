## Javascript Dependencies
## =======================
## These dependencies are drawn in by a node.js `require` invocation.
## This allows us to take advantage of the NPM package ecosystem and
## then bundle the app up for delivery as a client side app via `parcel.js`.

{.emit: "const createGraph = require('ngraph.graph');".}
{.emit: "const deepmerge = require('deepmerge');".}
{.emit: "const layout = require('ngraph.forcelayout3d');".}
{.emit: "const createWhisper = require('ngraph.cw');".}
{.emit: "const THREE = require('three');".}
{.emit: "const TWEEN = require('@tweenjs/tween.js');".}

const flyControls = staticRead("FlyControls.js")
{.emit: flyControls.}

const orbitControls = staticRead("OrbitControls.js")
{.emit: orbitControls.}
