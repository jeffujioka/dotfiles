#!/usr/bin/env bash
 
image="dotfiles:test"
container_name=dotfiles

# remove the container (force stop if it's running)
docker container rm -f $container_name > /dev/null 2>&1

USER=root

docker run -d \
  --user=$USER \
  -p127.0.0.1:3000:22 \
  --name $container_name \
  --workdir="$PWD" \
  -v "$PWD:$PWD" \
  -v "$HOME/.ssh:$HOME/.ssh" \
  "${image}"
