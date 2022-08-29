# Setup

Create a Python virtual environment in which we install a nodejs toolchain.

```
$ python -m venv venv
$ . venv/bin/activate
(venv) $ pip install nodeenv
(venv) $ nodeenv -p

(venv) $ cd frontend
(venv) $ npm install
(venv) $ npm build
```

To run the server,

```
# From the top-level directory.
(venv) $ python -m teleidoscope
```

# Upgrading

```
# Find all files that have the current version (e.g. 0.0.5) in them.
$ rg "0\.0\.5"
frontend/package.json
3:  "version": "0.0.5",

frontend/frontend.nimble
3:version       = "0.0.5"

CHANGELOG.md
3:## v0.0.5 - 2020-06-19

setup.py
12:    version="0.0.5",

teleidoscope/__init__.py
8:__version__ = "0.0.5"

frontend/package-lock.json
3:  "version": "0.0.5",
```

Ignore `CHANGELOG.md`.

Ignore `frontend/package-lock.json`, that will be automatically generated.

Change the version string in each file to the target version.

In the frontend directory run:

```
$ npm install
$ npm audit fix
```

Distribution Statement "A" (Approved for Public Release, Distribution
Unlimited).
