# Using DNS search domain to locate services


DNS resolution tools have capabilities to lookup from a more specific domain to a less specific.


## Running the example on Mac

You need boot2docker

```bash
eval "$(boot2docker shellinit)"
tar cf - bind | boot2docker ssh sudo tar xf -
boot2docker ssh 'cat > production.index.html' < production.index.html
boot2docker ssh 'cat > staging.index.html' < staging.index.html
export file_path="/home/docker"

./run.sh
```

The first time you run, the DNS will have misconfigured IP addresses, as those are dynamic.
Head to https://docker_host_ip:10000/ and log in with `root/password`.

Then navigate Sidebar > Servers > BIND DNS Server > Existing DNS Zones > example.com > Addresses and update the ips to what the output of ./run.sh set.

If you want to explore on a REPL, you can redefine the entrypoint on the client-container, eg:

```
docker run --rm --hostname=client.example.com --dns=172.17.0.7 --dns-search=. -ti client-lookup bash
```

## The client setup

The client host (or container) will have a full hostname set, including the environment it is running.
That is set with the -h|--hostname flag on docker.

Examples of FQDN:

- n01-client.example.com
- client.staging.example.com
- n01-client.dev.staging.example.com


Commands to check values on the host:

```
hostname -f
hostname -a
hostname -s

dnsdomainname
```

The /etc/resolv.conf must be configured with a DNS server to make the lookups.
The only expected entry is a `nameserver` entry. If there is no `domain` or `search` entry, it will get it based on the reported hostname from the previous commands.

On docker, `--dns-search=.` prevents additions of the hosts domain lookup in favor of the containers implicit FQDN discovery.

```
cat /etc/resolv.conf
```

The file will should have only the nameserver address that we will query. As our domain is a FQDN, the DNS resolver will be able to determine what is the domain.

- client.example.com querying for server => server.example.com
- client.staging.example.com querying for server => server.staging.example.com
- client.dev.example.com querying for server => server.dev.example.com
- n1.client.dev.example.com querying for server => server.client.dev.example.com (Warning!)

The domain search for FQDN is considered as everything after the first dot. That means if you have a n1.client.dev.example.com querying for server, it will not find what you want it to find.

## Overriding

There are some options to use another environment to fallback the lookup

- Configure the `search` parameter on `/etc/resolv.conf` to poin to the domain you want to lookup. eg:

Domain: n1.client.dev.example.com

resolv.conf line: `search dev.example.com example.com`

This way it will not use the search option will not be `client.dev.example.com` anymore, and it will search for both `server.dev.example.com` and `server.example.com`, with priority given the order of the list.

- Override per process

According to the man page of resolv.conf http://linux.die.net/man/5/resolv.conf, you can change the resolver on a process.
Setting the env variable `LOCALDOMAIN` will override the configuration on the resolver.


```
root@client:/# hostname
client.dev.example.com
root@client:/# cat /etc/resolv.conf
nameserver 172.17.0.16
root@client:/# LOCALDOMAIN=example.com curl http://server:8000
production
root@client:/# LOCALDOMAIN=staging.example.com curl http://server:8000
staging
```

- Hardcode the domain on `/etc/hosts`

```
root@client:/# echo 172.17.0.3 server >> /etc/hosts
root@client:/# curl http://server:8000
production
```


## Using Consul with the DNS interface

Consul is a distributed key value system, that also provides health
checks (with agents) and service discovery capabilities.

To simulate a cluster on a low resource manner, I'm going to use
Docker containers as lightweight computer units with differnt IP
addresses.

Running this example on Mac.
```bash
eval "$(boot2docker shellinit)"
boot2docker ssh 'cat > production.index.html' < production.index.html
boot2docker ssh 'cat > staging.index.html' < staging.index.html
export file_path="/home/docker"

./consul.sh
```

Consul was built with the idea of having multiple low latency cluster
rings, which they call datacenters (dc). It is suggested on a couple
of issues that you could run each dc as an environmnet. You could
effectively have two servers processes configured as different dc's on
the same VM to provide the idea of environments.  There will be two
cluster rings, the 'dev' dc and the 'staging' dc on the example.

The cluster is running with a single node (a docker container). They
communicate with each other over the WAN pool, so they can share
information between each other.

There is another container running consul on client mode, exposing a
web interface. It is aware of both clusters, so you can see all the
services on each ring.

After it stands up the "cluster", it will start two servers, one
configured to serve stagging and the other production.  After it is
up, we register on the service on the accordingly ring using the HTTP
interface of Consul. It's a JSON PUT request with the internal docker
ip to simulate an external node.

Consul has configured a DNS interface that queries for the service
when you ask for `[service-name].service.[dc].consul`. It returns
different addresses to each request and could be used as a load
balancer.

Than we combine what we've seen so far about the resolver in
combination with the hostname and search parameters on `resolv.conf`.
The client container is started with the hostname configured to match
the expected Consul format, but the search parameter could be modified
to lookup Consul instead of using the FQDN.

The container DNS resolver is also pointing to the same ip of the web
ui process. Each agent is capable of querying the cluster equally.
