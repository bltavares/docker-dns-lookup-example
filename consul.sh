#!/bin/bash -x
# Docker lookup experiment

#  Create the images
docker build -t server-lookup -f server.dockerfile .
docker build -t client-lookup -f client.dockerfile .

file_path=${file_path:-$(pwd)}

# Start a consul cluster of one node for prod environment
docker run -h consul.prod -d --name consul.prod progrium/consul -server -bootstrap -dc prod -log-level DEBUG
consul_prod_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' consul.prod)

# Start a consul cluster of one node for staging environment, and let then know that they are connected
docker run -h consul.staging -d --name consul.staging progrium/consul -server -bootstrap -dc staging -join-wan $consul_prod_ip
consul_staging_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' consul.staging)

# Start a consul web ui agent and connect it to prod. It should show both "regions" on the ui.
docker run -p 8400:8400 -p 8500:8500 -p 8600:53/udp -h consul.interface --name consul.interface \
  -d \
  progrium/consul \
  -ui-dir /ui \
  -dc prod -join $consul_prod_ip
consul_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' consul.interface)
echo 'Consul Web Interface available on your docker host at :8500'








# Start two servers, a staging one and a production one

# Start prod and register on the prod cluster
docker run -d \
  -h='server.example.com' \
  -v $file_path/production.index.html:/var/data/index.html \
  --name server.prod \
  server-lookup

prod_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' server.prod)
payload=$(cat <<EOF
{
  "ID": "server.prod",
  "Name": "server",
  "Address": "$prod_ip",
  "Port": 8000
}
EOF
)
docker run --rm client-lookup curl -X PUT -d "$payload" $consul_prod_ip:8500/v1/agent/service/register

# Start staging and register on the staging cluster
docker run -d \
  -h='server.staging.example.com' \
  -v $file_path/staging.index.html:/var/data/index.html \
  --name server.staging \
  server-lookup


staging_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' server.staging)
payload=$(cat <<EOF
{
  "ID": "server.staging",
  "Name": "server",
  "Address": "$staging_ip",
  "Port": 8000
}
EOF
)
docker run --rm client-lookup curl -X PUT -d "$payload" $consul_staging_ip:8500/v1/agent/service/register






echo The configuration should have staging pointing to $staging_ip and prod pointing to $prod_ip

echo The DNS server is running on $consul_ip and it should be configured to point to the correct ips
echo "server.service.prod.consul => $prod_ip"
echo "server.service.staging.consul => $staging_ip"






# Start a client with a consul dns registred for those

docker run \
  --rm \
  --hostname=client.service.prod.consul \
  --dns=$consul_ip \
  --dns-search=. \
  client-lookup

docker run \
  --rm \
  --hostname=client.service.staging.consul \
  --dns=$consul_ip \
  --dns-search=. \
  client-lookup

docker run \
  --rm \
  --hostname=client.service.dev.consul \
  --dns=$consul_ip \
  --dns-search=. \
  client-lookup
