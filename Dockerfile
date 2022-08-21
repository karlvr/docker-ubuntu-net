FROM ubuntu:20.04

RUN apt-get update && apt-get install -y net-tools iputils-ping traceroute iproute2 iptables dnsutils bind9-host netcat less
ENTRYPOINT sleep infinity
