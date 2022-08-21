FROM ubuntu:20.04

RUN apt-get update && apt-get install -y net-tools iputils-ping traceroute iproute2 iptables dnsutils bind9-host netcat less sudo mtr
RUN useradd --create-home --uid 1000 --shell /bin/bash --groups sudo ubuntu
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
CMD ["sleep", "infinity"]
USER 1000
