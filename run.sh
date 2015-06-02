#!/bin/bash
# Docker lookup experiment

#  Create the images
docker build -t server-lookup -f server.dockerfile .
docker build -t client-lookup -f client.dockerfile .

file_path=${file_path:-$(pwd)}
# Start two servers, a staging one and a production one

docker run -d -h='server.example.com' -v $file_path/production.index.html:/var/data/index.html --name prod server-lookup
docker run -d -h='server.staging.example.com' -v $file_path/staging.index.html:/var/data/index.html --name staging server-lookup

# Start a dns container
docker run --name='bind' -d -p 53/udp -v $file_path/bind:/data sameersbn/bind:latest

# Get the ip for those containers

prod_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' prod)
staging_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' staging)
bind_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' bind)

# Start a client with a fake dns registred for those

docker run \
  --rm \
  --hostname=client.example.com \
  --dns=$bind_ip \
  --dns-search=. \
  -ti client-lookup bash
