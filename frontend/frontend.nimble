# Package

version       = "0.0.5"
author        = "Eric Lee"
description   = "Graph Visualization UI"
license       = "Proprietary"
srcDir        = "src"
bin           = @["frontend.js"]
binDir        = "static"
backend       = "js"


# Dependencies

requires "nim >= 1.2.2"
requires "karax >= 1.1.2"


# Tasks
task clean, "Clean project directory":
  exec "find static ! -name '.gitignore' ! -name 'frontend.css' -type f -exec rm -f {} +"

task bundle, "Bundle js app":
  exec "./node_modules/.bin/parcel watch --public-url /static --out-dir ./static index.html static/frontend.js"
