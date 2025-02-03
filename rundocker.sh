#!/usr/bin/env bash
 
image="dotfiles:test"
container_name=dotfiles_test

# remove the container (force stop if it's running)
docker container rm -f $container_name > /dev/null 2>&1

U="$USER"

docker run \
  --user="$U" \
  --name $container_name \
  --workdir="$(pwd)" \
  -v "$(pwd):$(pwd)" \
  -it \
  ${image} bash
