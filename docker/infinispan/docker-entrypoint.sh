#!/bin/bash
echo "ARGS: $*"

set -e

BIND=$(find-hostname)
echo "BIND: $BIND"

SERVER=/opt/jboss/infinispan-server
LAUNCHER=$SERVER/bin/standalone.sh
CONFIG=clustered
BIND_OPTS="-Djboss.bind.address.management=0.0.0.0 -Djgroups.join_timeout=1000 -Djgroups.bind_addr=$BIND -Djboss.bind.address=$BIND"

if [ $# -ne 0 ] && [ -f $SERVER/standalone/configuration/$1.xml ]; then CONFIG=$1; shift; fi

# HAProxy
# We use HAProxy to bind to 0.0.0.0 on port 11224 and proxy to our bound address on 11222.
# This is what we bind the swarm port to, which proxies through to the actual hotrod endpoint.
# This is because hotrot doesn't appear to be able to bind to 0.0.0.0.
bind_addr=$BIND haproxy -f /etc/haproxy/haproxy.cfg

# Infinispan
exec $LAUNCHER -c $CONFIG.xml $BIND_OPTS "$@"
