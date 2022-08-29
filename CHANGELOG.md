### Changed

- allow special `viz.{red,green,blue}` tag color overrides

## v0.0.5 - 2020-06-19
Pre PI Meeting Changes.

- merge nodes and undo the implicit
- add deepmerge npm package to merge JsObjects
- remove yarn from the nodejs build system
- move from alpine images to slim (reduce build time)
- add community detection via Chinese Whisper
- upgrade to Nim 1.2.2
- upgrade to Karax 1.1.2
- search iterates/wraps properly through nodes
- searching from all focus options should work now
- allow search by storm node form
- two stage rendering to force edges behind nodes
- dark mode
- allow search by storm node value

## v0.0.4 - 2020-02-20
- graph info box changed to monospace font
- removed script focus option
- merged autofit and instructions focus options
- distinguish view (maybe better as page) and components in view.nim
- tweaked physics settings slightly

## v0.0.3 - 2020-02-20
- boto3 lookup by s3://bucket/object url
- frontend add search bar to search by s3 url
- canvas gets keydown rather than the window
- search bar works to search by tag (only first occurrence)
- bump nim to 1.0.4

## v0.0.2 - 2019-09-15

### Added
- cleaner load UIs
- loads graphs from MinIO
- using bulma.io as a CSS framework

### Changed
- replaced Sanic... don't ever use it

## v0.0.1 - 2018-10-18
Initial Version
