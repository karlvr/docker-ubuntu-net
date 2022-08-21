# Docker Ubuntu + Networking

An Ubuntu docker image with networking-related tools that doesn't need to run as root

Built from a basic Ubuntu image, this container adds a variety of networking-related tools that you might need to use to investigate networking inside a container network.

## Usage

Pull the latest version of the image:

```shell
docker pull karlvr/ubuntu-net
```

Run a shell inside the container:

```shell
docker run -it karlvr/ubuntu-net bash
```

Run the container so you can exec into a shell inside it later:

```shell
docker run -it karlvr/ubuntu-net
```

## Building

```shell
docker build -t karlvr/ubuntu-net .
```
