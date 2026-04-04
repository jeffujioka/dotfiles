#!/bin/sh

IMAGE_NAME="dotfiles:test"
DOCKERFILE="Dockerfile.test"

echo docker build                               
echo "   --build-arg DEV_HOME=$HOME"
echo "   --build-arg DEV_USER_NAME=$(id -un)"
echo "   --build-arg DEV_USER_PWD=1234"
echo "   --build-arg DEV_UID=$(id -u)"
echo "   --build-arg DOMAINUSERS_GID=$(id -g)"
echo "   --rm -t $IMAGE_NAME -f $DOCKERFILE docker"
docker build                                    \
    --build-arg DEV_HOME="$HOME"                \
    --build-arg DEV_USER_NAME="$(id -un)"       \
    --build-arg DEV_USER_PWD=1234               \
    --build-arg DEV_UID="$(id -u)"              \
    --build-arg DOMAINUSERS_GID="$(id -g)"      \
    --rm -t $IMAGE_NAME -f $DOCKERFILE docker
