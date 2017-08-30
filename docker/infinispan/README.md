# Infinispan docker container

```
docker build -t karlvr/letterboxd-infinispan .
```

Run the container:

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
