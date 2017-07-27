#!/bin/bash

# This script is a workaround due to inability to invoke bazel run targets from
# within bazel sandboxes. It is a simple shim over integration/main.go
# that accepts the same set of flags. Please add new flags to the Go test
# driver directly instead of extending this file.
#
# The additional steps that the script performs are:
# - set default docker tag based on a timestamp and user name
# - build and push docker images, including this repo pieces and proxy.

set -ex

DOCKER_IMAGE="istio-ca"

ARGS="--image $DOCKER_IMAGE"

HUB=""
TAG=""


while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG=$2
      shift
      ;;
    --hub)
      HUB=$2
      shift
      ;;
    *)
      ARGS="$ARGS $1"
  esac

  shift
done

if [[ -z $TAG ]]; then
  TAG=$(whoami)_$(date +%Y%m%d_%H%M%S)
fi
ARGS="$ARGS --tag $TAG"

if [[ -z $HUB ]]; then
  HUB="gcr.io/istio-testing"
fi
ARGS="$ARGS --hub $HUB"

if [[ "$HUB" =~ ^gcr\.io ]]; then
  gcloud docker --authorize-only
fi

# Build and push the Istio-CA docker image
bazel run $BAZEL_ARGS //docker:$DOCKER_IMAGE
docker tag bazel/docker:$DOCKER_IMAGE $HUB/$DOCKER_IMAGE:$TAG
docker push $HUB/$DOCKER_IMAGE:$TAG

# Run integration tests
bazel run $BAZEL_ARGS //integration -- $ARGS -k $HOME/.kube/config --alsologtostderr
