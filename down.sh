#!/usr/bin/env bash
set -o errexit

# Reset the volumes
if [ -f "docker-compose.yml" ]
then
    docker-compose --log-level ERROR down
fi