# Infinispan docker container

## Staging

We create an Infinispan service on our swarm, running on its own overlay network. We publish a hotrod port (11222) on 
the swarm, which will connect to any of the running containers, and each container also listens for hotrod on the
overlay network.

When a basic client connects to that port it happily communicates with whichever Infinispan node it finds. When a 
topology aware client connects, it exchanges topology information and discovers the overlay network addresses of the nodes.

We place a router container in the overlay network, and set static routing rules for the overlay network's subnet on
the node, and on other systems on the network that need to communicate with Infinispan.

### Setup the Docker environment

We need to create the overlay network that will run across the swarm (make a swarm if you haven't already). The network
needs to be attachable, as we will run containers on it manually and as part of a service:

```
docker network create -d overlay --attachable ubernet
```

Create a router on the server that will act as the router into the overlay network. Note that 10.0.0.0/24 is the subnet of `ubernet` (check that it is in your setup):

```
docker run --privileged --network ubernet -d --name router --restart always karlvr/router
route add -net 10.0.0.0/24 gw <docker_gwbridge ip of the router container>
```

Because the container has to run in privileged mode it isn't possible to make it a service.

### Shorewall

On each server hosting Docker, we need to setup masquerading so that the private container network can access external resources.

Add the following to `/etc/shorewall/masq`:

```
p2p1	172.18.0.0/12
```

(Replace `172.18.0.0/12` with whatever the network on `docker_gwbridge` is: `docker network inspect docker_gwbridge`)

### Create the Infinispan service

```
docker service create --replicas 2 -p 11222:11222 --name infinispan --network ubernet --with-registry-auth karlvr/letterboxd-infinispan letterboxd -Djboss.default.jgroups.stack=tcp
```

### Setup development machines to access staging

We need a static route from development machines so that they can talk directly to the Infinispan containers. We have added a classless static
route to our DHCP server, so you don't need to do this manually on each machine!

The DHCP configuration looks like:

```
option classless-routes code 121 = array of unsigned integer 8;

subnet ... {
	option classless-routes 24, 10, 0, 0, 10, 1, 10, 7;
}
```

The above configuration defines the network as 10.0.0/24 and the router as 10.1.10.7.

If you want to manually configure a host:

```
sudo route add -net 10.0.0.0 10.1.10.7 255.255.255.0
```

## Production

```
docker network create -d overlay --attachable --subnet=10.100.100.0/24 infinispan
docker run --privileged --network infinispan -d --name router --restart always --env internalSubnet=10.100.100.0/24 karlvr/router
route add -net 10.100.100.0/24 gw <docker_gwbridge ip of the router container>

docker service create --replicas 2 -p 11224:11222 --name infinispan --network infinispan --with-registry-auth karlvr/letterboxd-infinispan letterboxd -Djboss.default.jgroups.stack=tcp -Djboss.jgroups.jdbc_ping.username=letterboxd -Djboss.jgroups.jdbc_ping.password=x44zpyj6 -Djboss.jgroups.jdbc_ping.url=jdbc:postgresql://10.100.10.1/letterboxd
```

## Development

```
docker build -t karlvr/letterboxd-infinispan .
```

Run the container on a local Docker:

```
docker run -it -p 11222:11222 karlvr/letterboxd-infinispan letterboxd -Djboss.default.jgroups.stack=tcp
```

Note that on macOS, in order for HotRod to work, you need to add an `external-host` element in `letterboxd.xml` before you
build the container, as below. This is because Docker networking on macOS doesn't let the host network to the container
properly.

```
            <hotrod-connector socket-binding="hotrod" cache-container="clustered82">
                <topology-state-transfer external-host="localhost" lazy-retrieval="false" lock-timeout="1000" replication-timeout="5000"/>
            </hotrod-connector>
```

Test the container looks okay:

```
docker run -it --entrypoint /bin/bash karlvr/letterboxd-infinispan
```

Push the container to the repository:

```
docker push karlvr/letterboxd-infinispan
```

Pull the container from the repository on another machine:

```
docker pull karlvr/letterboxd-infinispan
```

Run the container:

```
docker run -it karlvr/letterboxd-infinispan letterboxd -Djboss.default.jgroups.stack=tcp
```

Create a service to run the container:

```
docker service create --replicas 2 -p 11222:11222 --name infinispan --with-registry-auth karlvr/letterboxd-infinispan letterboxd -Djboss.default.jgroups.stack=tcp
```

Check the status of the service:

```
docker service ls
docker service inspect --pretty infinispan
docker ps
```

If the image has changed, and you want to update the image:

```
docker service update --image karlvr/letterboxd-infinispan --with-registry-auth infinispan
```

Just restart the service:

```
docker service update --force infinispan
```

Delete the service:

```
docker service rm infinispan
```
