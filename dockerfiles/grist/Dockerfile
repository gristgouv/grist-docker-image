ARG GRIST_VERSION=1.6.1

################################################################################
## The Grist source can be extended. This is a stub that can be overridden
## from command line, as:
##   docker buildx build -t ... --build-context=ext=<path> .
## The code in <path> will then be built along with the rest of Grist.
################################################################################
FROM scratch AS ext

################################################################################
# Get sources from git stage
################################################################################
FROM alpine/git:v2.47.2 AS sources

ARG GRIST_VERSION

# Clone grist from GRIST_VERSION tag
WORKDIR /grist-core
RUN \
  git clone --depth 1 -b v$GRIST_VERSION https://github.com/gristlabs/grist-core.git .

################################################################################
## Javascript build stage
################################################################################

FROM node:22.17.0-alpine3.21 AS builder

# Install all node dependencies.
WORKDIR /grist
COPY --from=sources /grist-core/package.json /grist-core/yarn.lock /grist/

# Add python and build tools needed by gyp compilation in node modules
RUN \
  apk add --no-cache python3 build-base

# Create node_modules with devDependencies to be able to build the app
# Add at global level gyp deps to build sqlite3 for prod
# then create node_modules_prod that will be the node_modules of final image
RUN \
  yarn install --frozen-lockfile --verbose --network-timeout 600000 && \
  yarn global add --verbose --network-timeout 600000 node-gyp node-pre-gyp node-gyp-build node-gyp-build-optional-packages && \
  yarn install --prod --frozen-lockfile --modules-folder=/node_modules_prod --verbose --network-timeout 600000

# Install any extra node dependencies (at root level, to avoid having to wrestle
# with merging them).
COPY --from=ext / /grist/ext
RUN \
 mkdir /node_modules && \
 cd /grist/ext && \
 { if [ -e package.json ] ; then yarn install --frozen-lockfile --modules-folder=/node_modules --verbose --network-timeout 600000 ; fi }

# Build node code.
COPY --from=sources /grist-core/tsconfig.json /grist
COPY --from=sources /grist-core/tsconfig-ext.json /grist
COPY --from=sources /grist-core/tsconfig-prod.json /grist
COPY --from=sources /grist-core/app /grist/app
COPY --from=sources /grist-core/stubs /grist/stubs
COPY --from=sources /grist-core/buildtools /grist/buildtools
# Copy locales files early. During build process they are validated.
COPY --from=sources /grist-core/static/locales /grist/static/locales

# Add bash needed by build:prod
# And then build prod
RUN \
  apk add --no-cache bash && \
  yarn run build:prod && \
# We don't need them anymore, they will by copied to the final image.
  rm -rf /grist/static/locales

################################################################################
## Python collection stage
################################################################################

# Fetch python3.11
FROM python:3.11.11-alpine3.21 AS collector-py3
COPY --from=sources /grist-core/sandbox/requirements.txt requirements.txt
RUN \
  pip3 install --no-cache-dir pip==25.0.1 setuptools==75.8.1 && \
  pip3 install --no-cache-dir -r requirements.txt

################################################################################
## Sandbox collection stage
################################################################################

# Fetch gvisor-based sandbox. Note, to enable it to run within default
# unprivileged docker, layers of protection that require privilege have
# been stripped away, see https://github.com/google/gvisor/issues/4371
# The standalone sandbox binary is built on buster, but remains compatible
# with recent Debian.
# If you'd like to use unmodified gvisor, you should be able to just drop
# in the standard runsc binary and run the container with any extra permissions
# it needs.
FROM docker.io/gristlabs/gvisor-unprivileged:buster AS sandbox

################################################################################
## Run-time stage
################################################################################

# Now, start preparing final image.
FROM alpine:3.21.3

# Install curl for docker healthchecks, libexpat1 and (libsqlite3-0 maybe we need to put it back) for python3
# library binary dependencies, and procps for managing gvisor processes.
# Bash to run image entrypoint
# setpriv is used in docker_entrypoint.sh
# dirty symbolic link to follow docker_entrypoint.sh expectations
# NOTE: icu-data-full is required for Intl API (Internationalization) support in NodeJS.
# Otherwise the API only supports en-US format.
RUN \
  apk --no-cache add bash curl libexpat nodejs icu-data-full procps-ng setpriv tini && \
  ln -s /sbin/tini /usr/bin/tini

# Keep all storage user may want to persist in a distinct directory
RUN mkdir -p /persist/docs

# Copy node files.
COPY --from=builder /node_modules /node_modules
COPY --from=builder /node_modules_prod /grist/node_modules
COPY --from=builder /grist/_build /grist/_build
COPY --from=builder /grist/static /grist/static-built

# Copy python3 files.
COPY --from=collector-py3 /usr/local/bin/python3.11 /usr/bin/python3.11
COPY --from=collector-py3 /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=collector-py3 /usr/local/lib/libpython3.11.* /usr/local/lib/
# Set default to python3

RUN \
  ln -s /usr/bin/python3.11 /usr/bin/python &&\
  ln -s /usr/bin/python3.11 /usr/bin/python3 && \
  ldconfig /etc/ld.so.conf.d

# Copy runsc.
COPY --from=sandbox /runsc /usr/bin/runsc

# Add files needed for running server.
COPY --from=sources /grist-core/package.json /grist/package.json
COPY --from=sources /grist-core/bower_components /grist/bower_components
COPY --from=sources /grist-core/sandbox /grist/sandbox
COPY --from=sources /grist-core/plugins /grist/plugins
COPY --from=sources /grist-core/static /grist/static

# Finalize static directory
RUN \
  mv /grist/static-built/* /grist/static && \
  rmdir /grist/static-built

# To ensure non-root users can run grist, 'other' users need read access (and execute on directories)
# This should be the case by default when copying files in.
# Only uncomment this if running into permissions issues, as it takes a long time to execute on some systems.
# RUN chmod -R o+rX /grist

# Add a user to allow de-escalating from root on startup
RUN adduser -Ds /bin/bash grist
ENV GRIST_DOCKER_USER=grist \
    GRIST_DOCKER_GROUP=grist
WORKDIR /grist

# Set some default environment variables to give a setup that works out of the box when
# started as:
#   docker run -p 8484:8484 -it <image>
# Variables will need to be overridden for other setups.
#
# GRIST_SANDBOX_FLAVOR is set to unsandboxed by default, because it
# appears that the services people use to run docker containers have
# a wide variety of security settings and the functionality needed for
# sandboxing may not be possible in every case. For default docker
# settings, you can get sandboxing as follows:
#   docker run --env GRIST_SANDBOX_FLAVOR=gvisor -p 8484:8484 -it <image>
#
# "NODE_OPTIONS=--no-deprecation" is set because there is a punycode
# deprecation nag that is relevant to developers but not to users.
# TODO: upgrade package.json to avoid using all package versions
# using the punycode functionality that may be removed in future
# versions of node.
#
# "NODE_ENV=production" gives ActiveDoc operations more time to
# complete, and the express webserver also does some streamlining
# with this setting. If you don't want these, set NODE_ENV to
# development.
#
ENV \
  PYTHON_VERSION=3 \
  GRIST_ORG_IN_PATH=true \
  GRIST_HOST=0.0.0.0 \
  GRIST_SINGLE_PORT=true \
  GRIST_SERVE_SAME_ORIGIN=true \
  GRIST_DATA_DIR=/persist/docs \
  GRIST_INST_DIR=/persist \
  GRIST_SESSION_COOKIE=grist_core \
  GVISOR_FLAGS="-unprivileged -ignore-cgroups" \
  GRIST_SANDBOX_FLAVOR=gvisor \
  NODE_OPTIONS="--no-deprecation" \
  NODE_ENV=production \
  TYPEORM_DATABASE=/persist/home.sqlite3

EXPOSE 8484

ENTRYPOINT ["./sandbox/docker_entrypoint.sh"]
CMD ["node", "./sandbox/supervisor.mjs"]
