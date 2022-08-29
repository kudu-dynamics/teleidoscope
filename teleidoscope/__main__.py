from base64 import b64decode
from contextlib import suppress
import gzip
import json
import os
import sys
from typing import Dict, Generator
import urllib.parse

import boto3
from botocore.exceptions import ClientError
from fastapi import FastAPI, HTTPException
from fastapi.encoders import jsonable_encoder
from starlette.responses import HTMLResponse, JSONResponse
from starlette.staticfiles import StaticFiles
from starlette.websockets import WebSocket
import uvicorn

from teleidoscope import __version__, load_tpx_archive


S3 = boto3.resource(
    "s3",
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    endpoint_url=os.getenv("AWS_ENDPOINT_URL"),
)
STATIC_DIR = os.getenv("STATIC_DIR", "./frontend/static")


def tpx_to_msg(entry: Dict) -> Generator[Dict, None, None]:
    path = entry.get("path", [])
    for i, node in enumerate(path):
        # Emit messages for the nodes.
        yield json.dumps({"type": "node", "node": list(node)})
        # Emit messages for the edges.
        if i > 0:
            yield json.dumps(
                {
                    "type": "edge",
                    "node1": list(path[i - 1]),
                    "node2": list(node),
                }
            )


def main(argv=None):  # noqa: C901
    if not os.getenv("AWS_ACCESS_KEY_ID", None) or not os.getenv(
        "AWS_SECRET_ACCESS_KEY", None
    ):
        print("Need to set the following Environment Variables:")
        print("    AWS_ACCESS_KEY_ID")
        print("    AWS_SECRET_ACCESS_KEY")
        print("    AWS_ENDPOINT_URL")
        return 1

    app = FastAPI(
        title="Teleidoscope API",
        openapi_prefix=os.getenv("OPENAPI_PREFIX", "/"),
        version=__version__,
    )
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

    @app.get("/", include_in_schema=False)
    def root():
        with open(f"{STATIC_DIR}/index.html") as fd:
            return HTMLResponse(fd.read())

    @app.get("/v1/version")
    def version():
        return JSONResponse(content=jsonable_encoder({"version": __version__}))

    @app.post("/v1/graphs")
    def graphs(body: Dict):
        path = body.get("path", None)
        if not path:
            return JSONResponse(status_code=400, content={"message": "Missing 'path' from request body"})

        # Sanitize the input.
        if path.startswith("s3://"):
            path = path.replace("s3://", "")

        # Validate the existence of the object.
        bucket, key = path.split('/', maxsplit=1)
        obj = S3.Object(bucket, key)
        try:
            obj.metadata
        except ClientError as e:
            response = getattr(e, "response", {})
            status_code = response.get("ResponseMetadata", {}).get("HTTPStatusCode", 400)
            return JSONResponse(status_code=status_code, content={"message": response})

        # Return successfully if the object was found.
        return JSONResponse(status_code=200, content={"message": "object found"})

    @app.websocket("/v1/graphs/{path}/ws")
    async def graphsocket(websocket: WebSocket, path: str):
        await websocket.accept()

        # The path is passed in uri-encoded.
        path = urllib.parse.unquote(path)
        path = b64decode(path).decode()

        try:
            bucket, key = path.split('/', maxsplit=1)
            obj = S3.Object(bucket, key)

            buf = obj.get()["Body"]
            with gzip.GzipFile(fileobj=buf, mode="rb") as fd:
                for entry in load_tpx_archive(fd):
                    # { "path": { ... } }
                    # { "path": { ... } }
                    # ...
                    for msg in tpx_to_msg(entry):
                        await websocket.send_text(msg)
        except ClientError as e:
            response = getattr(e, "response", {})
            status_code = response.get("ResponseMetadata", {}).get("HTTPStatusCode", 400)
            # XXX: Close the websocket connection properly.
            raise HTTPException(detail=json.dumps(response), status_code=404)

    uvicorn.run(
        app,
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "5000")),
        reload=bool(int(os.getenv("DEBUG", "0"))),
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
