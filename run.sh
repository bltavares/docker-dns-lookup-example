#!/bin/bash -x
# Docker lookup experiment

#  Create the images
docker build -t server-lookup -f server.dockerfile .
docker build -t client-lookup -f client.dockerfile .

file_path=${file_path:-$(pwd)}
# Start two servers, a staging one and a production one

docker run -d -h='server.example.com' -v $file_path/production.index.html:/var/data/index.html --name prod server-lookup
docker run -d -h='server.staging.example.com' -v $file_path/staging.index.html:/var/data/index.html --name staging server-lookup

# Start a dns container
docker run --name='bind' -d -p 53/udp -p 10000:10000 -v $file_path/bind:/data -e ROOT_PASSWORD=password sameersbn/bind:latest

# Get the ip for those containers

prod_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' prod)
staging_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' staging)
echo The configuration should have staging pointing to $staging_ip and prod pointing to $prod_ip

bind_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' bind)
echo The DNS server is running on $bind_ip and it should be configured manually to point to the correct ips
echo "server.example.com => $prod_ip"
echo "server.staging.example.com => $staging_ip"

# Start a client with a fake dns registred for those

docker run \
  --rm \
  --hostname=client.example.com \
  --dns=$bind_ip \
  --dns-search=. \
  client-lookup

docker run \
  --rm \
  --hostname=client.staging.example.com \
  --dns=$bind_ip \
  --dns-search=. \
  client-lookup

docker run \
  --rm \
  --hostname=client.dev.example.com \
  --dns=$bind_ip \
  --dns-search=. \
  client-lookup
