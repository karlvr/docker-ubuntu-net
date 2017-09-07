FROM ubuntu

RUN apt-get update && apt-get install -y net-tools iputils-ping traceroute iproute2
ENTRYPOINT sleep infinity
