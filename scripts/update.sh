#!/bin/sh
#
# This script fetches the latest docker/compose, psf/black, and PyCQA release
# and automatically build and push to dockerhub is not there yet
#
# Invoked by a scheduled GitHub Action

set -eu

DOCKER_REPO="${DOCKER_REPO:-"aantonw/compose-pyqa"}"
BLACK_URL="https://api.github.com/repos/psf/black/releases/latest"
COMPOSE_URL="https://api.github.com/repos/docker/compose/releases/latest"
ISORT_URL="https://api.github.com/repos/PyCQA/isort/releases/latest"
BLACK_VERSION=""
COMPOSE_VERSION=""
ISORT_VERSION=""

# Fetch latest release from the GitHub API.
if [ "${BLACK_VERSION:-}" = "" ]; then
    BLACK_VERSION="$(curl -s ${BLACK_URL} | jq -r .tag_name)"
    if [ "${BLACK_VERSION}" = "" ]; then
        echo "Could not get latest release from ${BLACK_URL}"
        exit 1
    else
        echo "Found latest black release ${BLACK_VERSION}"
    fi
fi
if [ "${COMPOSE_VERSION:-}" = "" ]; then
    COMPOSE_VERSION="$(curl -s ${COMPOSE_URL} | jq -r .tag_name)"
    if [ "${COMPOSE_VERSION}" = "" ]; then
        echo "Could not get latest release from ${COMPOSE_URL}"
        exit 1
    else
        echo "Found latest docker-compose release ${COMPOSE_VERSION}"
    fi
fi
if [ "${ISORT_VERSION:-}" = "" ]; then
    ISORT_VERSION="$(curl -s ${ISORT_URL} | jq -r .tag_name)"
    if [ "${ISORT_VERSION}" = "" ]; then
        echo "Could not get latest release from ${ISORT_URL}"
        exit 1
    else
        echo "Found latest isort release ${ISORT_VERSION}"
    fi
fi

DOCKER_IMAGE_TAG=compose-${COMPOSE_VERSION}_black-${BLACK_VERSION}_isort-${ISORT_VERSION}
COMPOSE_BIN_URL=https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)

# Fetch a temporary docker auth token if necessary (the automated workflow
# includes its own dedicated token).
DOCKERHUB_TOKEN=$(curl -s "https://auth.docker.io/token?scope=repository:${DOCKER_REPO}:pull&service=registry.docker.io" | jq -r '.token')
if [ "${DOCKERHUB_TOKEN}" = "" ]; then
    echo "Could not get docker auth token for repo ${DOCKER_REPO}"
    exit 1
fi

# See if an image already exists. If so, we can exit early, no more work to do.
TAG_LIST=$(curl -s -H "Authorization: Bearer ${DOCKERHUB_TOKEN}" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry.hub.docker.com/v2/${DOCKER_REPO}/tags/list")
set +e
echo $TAG_LIST | grep -q $DOCKER_IMAGE_TAG
TAG_EXISTS=$?
set -e

if [ $TAG_EXISTS -eq 0 ]; then
    echo "Image ${DOCKER_REPO}:${DOCKER_IMAGE_TAG} already exists, skipping."
    exit 0
fi

# Otherwise, build and push a new image.
echo "Building  ${DOCKER_REPO}:${DOCKER_IMAGE_TAG} ..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t "${DOCKER_REPO}:${DOCKER_IMAGE_TAG}" \
    -t "${DOCKER_REPO}:latest" \
    --build-arg COMPOSE_BIN_URL="${COMPOSE_BIN_URL}" \
    --build-arg BLACK_VERSION="${BLACK_VERSION}" \
    --build-arg ISORT_VERSION="${ISORT_VERSION}" \
    --push \
    "."