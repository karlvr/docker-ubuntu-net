#!/bin/bash
echo "ARGS: $*"

set -e

BIND=$(find-hostname)
echo "BIND: $BIND"

SERVER=/opt/jboss/infinispan-server
LAUNCHER=$SERVER/bin/standalone.sh
CONFIG=clustered
BIND_OPTS="-Djboss.bind.address.management=0.0.0.0 -Djgroups.join_timeout=1000 -Djgroups.bind_addr=$BIND -Djboss.bind.address=$BIND -Djboss.bind.address.hotrod=0.0.0.0"

if [ $# -ne 0 ] && [ -f $SERVER/standalone/configuration/$1.xml ]; then CONFIG=$1; shift; fi

# Infinispan
exec $LAUNCHER -c $CONFIG.xml $BIND_OPTS "$@"
