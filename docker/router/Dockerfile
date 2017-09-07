# A simple container that routes from the external network into an overlay network.
# The overlay network's subnet must be 10.0.0.0/24 currently

FROM ubuntu

RUN apt-get update && apt-get install -y net-tools iputils-ping traceroute iproute2 iptables tcpdump netcat && apt-get clean

# Fix tcpdump from apparmor interference?
RUN mv /usr/sbin/tcpdump /usr/bin/tcpdump

ENTRYPOINT sysctl net.ipv4.ip_forward=1 && iptables -t nat -A POSTROUTING ! -s 10.0.0.0/24 -j MASQUERADE && sleep infinity
