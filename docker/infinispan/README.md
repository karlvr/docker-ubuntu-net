# Infinispan docker container

## Staging

We create an Infinispan service on our swarm, running on its own overlay network. We publish a hotrod port (11222) on 
the swarm, which will connect to any of the running containers.

When a basic client connects to that port it happily communicates with whichever Infinispan node it finds. When a 
topology aware client connects, it exchanges topology information and discovers the direct addresses of the nodes.
That is why we place a router container in the overlay network, and set static routing rules to the overlay network
on our network.

### Setup the Docker environment

We need to create the overlay network that will run across the swarm (make a swarm if you haven't already).

```
docker network create -d overlay ubernet
```

Create a router on the server that will act as the router into the overlay network. Note that 10.0.0.0/24 is the subnet of ubernet (check that it is in your setup).

```
docker run --privileged --network ubernet -d karlvr/router
route add -net 10.0.0.0/24 gw <docker_gwbridge ip of the router container>
```

### Create the Infinispan service

```
docker service create --replicas 2 -p 11222:11224 --name infinispan --network ubernet --with-registry-auth karlvr/letterboxd-infinispan letterboxd -Djboss.default.jgroups.stack=tcp
```

### Setup development machines to access staging

We need a static route from development machines so that they can talk directly to the Infinispan containers.

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

Delete the service:

```
docker service rm infinispan
```
