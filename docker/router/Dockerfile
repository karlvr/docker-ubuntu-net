# A simple container that helps route the container's internal network (such as
# a swarm overlay network) outside the container. This lets external hosts route
# packets to containers on the internal network.
# 
# The internal network's subnet defaults to 10.0.0.0/24 and can be configured
# using the internalSubnet environment variable.

FROM ubuntu

ENV internalSubnet 10.0.0.0/24

RUN apt-get update && apt-get install -y net-tools iputils-ping traceroute iproute2 iptables tcpdump netcat && apt-get clean

# Fix tcpdump from apparmor interference?
RUN mv /usr/sbin/tcpdump /usr/bin/tcpdump

ENTRYPOINT sysctl net.ipv4.ip_forward=1 && iptables -t nat -A POSTROUTING ! -s ${internalSubnet} -j MASQUERADE && sleep infinity
