FROM ubuntu:24.04

RUN apt-get update && apt-get install -y net-tools iputils-ping traceroute iproute2 iptables dnsutils bind9-host netcat-openbsd less sudo mtr screen curl

# Fix ping so we can use it without cap_net_raw, such as in a locked-down container but with
#   sysctl -w net.ipv4.ping_group_range=0 65535
# See https://www.antitree.com/2019/01/containers-using-ping-without-cap_net_raw/
#
# We remove the effective bit so it only fails if it actually needs the capability
# See https://projectatomic.io/blog/2015/04/problems-with-ping-in-containers-on-atomic-hosts/
RUN setcap cap_net_raw+p /usr/bin/ping
RUN setcap cap_net_raw+p /usr/bin/mtr-packet

RUN usermod --append --groups sudo ubuntu && \
	echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
CMD ["sleep", "infinity"]
USER 1000
WORKDIR /home/ubuntu
