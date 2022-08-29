# Download Node.js dependencies.
FROM node:11.2-slim AS node-deps
COPY frontend/package.json frontend/package-lock.json /build/
WORKDIR /build/
RUN npm install
# Artifact -> /build/node_modules

# --------------------------------------------------------------------------- #

# Build Nim frontend.
FROM nimlang/nim:1.2.2-alpine AS nim-build
COPY frontend/frontend.nimble /build/
COPY frontend/src /build/src
WORKDIR /build/
RUN nimble build -y
# Artifact -> /build/static/frontend.js

# --------------------------------------------------------------------------- #

# Run browserify and bundle the frontend app.
FROM node-deps AS node-build
COPY --from=nim-build /build/static/frontend.js /build/static/
COPY frontend/index.html /build/
COPY frontend/static/frontend.css /build/static/
WORKDIR /build/
RUN npm run build
# Artifact -> /build/static/*

# --------------------------------------------------------------------------- #

# Build Python backend.
FROM python:3.7-slim
COPY --from=node-build /build/static/* /static/
COPY README.md setup.py /build/
COPY teleidoscope /build/teleidoscope
RUN pip install /build/

WORKDIR /
ENV STATIC_DIR /static
EXPOSE 5000/tcp
VOLUME ["/graphs"]
ENTRYPOINT ["python", "-m", "teleidoscope"]
