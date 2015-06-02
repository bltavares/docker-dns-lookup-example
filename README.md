#!/bin/bash
# Docker lookup experiment

#  Create the images
docker build -t server-lookup -f server.dockerfile .
docker build -t client-lookup -f client.dockerfile .

# Start two servers, a staging one and a production one

docker run -d -h='server.example.com' -v $(pwd)/production.index.html:/var/data/index.html --name prod server-lookup
docker run -d -h='server.staging.example.com' -v $(pwd)/staging.index.html:/var/data/index.html --name staging server-lookup

# Get the ip for those containers

prod_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' prod)
staging_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' staging)

# Start a client with a fake dns registred for those

docker run \
  --rm \
  --add-host=server.example.com:$prod_ip \
  --add-host=server.staging.example.com:$staging_ip \
  --hostname=client.example.com \
  --dns-search=. \
  -ti client-lookup bash
