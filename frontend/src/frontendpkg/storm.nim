import algorithm, jsffi, sequtils, strutils, sugar

import gradient

var
  deepmerge {.importc: "deepmerge".}: proc(a, b: JsObject): JsObject

const
  TagsOfInterest = @[
    "aka",
    "cno.mal",
    "cno.threat",
    "pub",
    "rep.vt.cve",
    "rep.vt.exploit",
  ]

var
  Array {.importc, nodecl.}: JsObject
  JSON {.importc, nodecl.}: JsObject

type
  StormNode* = distinct JSObject
  StormNdef* = distinct JSObject
  StormInfo* = distinct JSObject

proc is_storm_node*(obj: JsObject): bool =
  if obj.isNull():
    return false
  if obj.isUndefined():
    return false
  # ndef
  if obj[0].isUndefined():
    return false
  # info
  if obj[1].isUndefined():
    return false
  # form
  if obj[0][0].isUndefined():
    return false
  # valu
  if obj[0][1].isUndefined():
    return false
  return true

proc ndef*(node: StormNode): StormNdef = StormNdef(node.js[0])
proc info*(node: StormNode): StormInfo = StormInfo(node.js[1])
# DEV: Use the form valu as an iden instead of the value that Synapse uses.
proc iden*(node: StormNode): string = $JSON.stringify(node.ndef.js).to(cstring)
proc form*(ndef: StormNdef): string = $ndef.js[0].to(cstring)
proc valu*(ndef: StormNdef): string = $JSON.stringify(ndef.js[1]).to(cstring)
iterator tags*(info: StormInfo): string =
  if info.js["tags"] != jsUndefined:
    # The tags property can be either an object or an array.
    if Array.isArray(info.js["tags"]).to(bool):
      for tag in info.js["tags"]:
        yield $tag.to(cstring)
    else:
      for tag in info.js["tags"].keys:
        yield $tag
proc props*(info: StormInfo): JsObject = info.js["props"]

proc merge*(a, b: StormNode): StormNode =
  # Handle 'props'.
  var mprops: JsObject
  if a.info().props.isUndefined():
    mprops = b.info().props
  elif b.info().props.isUndefined():
    mprops = a.info().props
  else:
    mprops = deepmerge(a.info().props, b.info().props)
  # Handle 'tags'.
  # DEV: As JavaScript serialized arrays are expected to have native strings,
  #      we need to be careful to convert all `string`s to `cstring`s before
  #      reserializing them.
  var mtags: seq[cstring] = @[]
  for tag in a.info().tags():
    let ctag = cstring(tag)
    if ctag notin mtags:
      mtags.add(ctag)
  for tag in b.info().tags():
    let ctag = cstring(tag)
    if ctag notin mtags:
      mtags.add(ctag)
  mtags.sort()
  # Return the new merged node.
  let ndef = a.ndef()
  var node: JsObject = js{
    0: ndef,
    1: js{
      "props": mprops,
      "tags": mtags,
    },
  }
  result = StormNode(node)

var
  unknown_forms: seq[string] = @[]
    ## Keep track of the unknown forms that have been seen and assign a randomly
    ## generated color.
  form_colors: seq[int] = @[]

proc style*(node: StormNode): tuple[color: int, size: float] =
  result = (color: 0xFF00FF, size: 10.0)
  let form = node.ndef().form()
  case form:
    of "file:bytes":
      result = (color: 0x00FF00, size: 80.0)
    of "file:mime:pe:section":
      result = (color: 0x42F4DC, size: 25.0)
    of "hash:sha256":
      result = (color: 0x3322DD, size: 20.0)
    of "it:reveng:function":
      result = (color: 0xFFA500, size: 100.0)
    else:
      if not (form in unknown_forms):
        unknown_forms.add(form)
        form_colors = concat(form_colors, toSeq(defaultGradient(
          unknown_forms.len - 1, unknown_forms.len
        )))
      let form_color = form_colors[unknown_forms.find(form)]
      result = (color: form_color, size: 15.0)
  for tag in node.info.tags:
    if tag.startswith("viz.red") or tag.startswith("viz.color.red"):
      result.color = 0xFF0000
    elif tag.startswith("viz.green") or tag.startswith("viz.color.green"):
      result.color = 0x00FF00
    elif tag.startswith("viz.blue") or tag.startswith("viz.color.blue"):
      result.color = 0x0000FF
    elif TagsOfInterest.any(pattern => tag.startswith(pattern)):
      result.color = 0xFF0000
