FROM ubuntu

ENV varnishBackend apache:80

RUN apt-get update && apt-get install -y curl less
RUN curl -s https://packagecloud.io/install/repositories/varnishcache/varnish41/script.deb.sh | bash
RUN apt-get install -y varnish
COPY vmods/* /usr/lib/varnish/vmods/
RUN apt-get install -y libgeoip1 libmhash2
COPY etc /etc/varnish
COPY entrypoint.sh /

ENTRYPOINT /entrypoint.sh
EXPOSE 80 6082

# To run varnishadm:
# docker exec -it <container> varnishadm
#
# e.g. docker exec -it <container> varnishadm backend.list -p

# BACKENDS

# Perhaps use this director to access a DNS round-robin web backend docker service:
# https://github.com/nigoroll/libvmod-dynamic
# This branch supports Varnish 4: https://github.com/nigoroll/libvmod-dynamic/tree/5.0

# Or see this repo where they've used a script to do a DNS lookup periodically
# and if the list of IPs change, they rewrite the VCL and reload Varnish
# https://github.com/eea/eea.docker.varnish

# But see this article about the disadvantages of reloading VCL:
# https://info.varnish-software.com/blog/vmod-goto-your-go-to-guy-for-dynamic-backends

# In order to have the service be DNS round-robin instead of virtual IP
# you must start it with the --endpoint-mode dnsrr flag. Then inside a container
# on the same network, the service name will resolve to multiple hosts.
# Check using: getent hosts <service name>

# TODO: detect available memory
# e.g. they do it in Infinispan https://github.com/jboss-dockerfiles/infinispan/blob/master/server/docker-entrypoint.sh
