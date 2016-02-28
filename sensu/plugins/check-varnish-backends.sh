#!/bin/bash -e

VARNISHADM=varnishadm
VARNISHADDRESS=localhost:6082
VARNISHSECRET=/etc/varnish/secret-sensu
NAME=CheckVarnishBackends

OUTPUT=$("$VARNISHADM" -T "$VARNISHADDRESS" -S "$VARNISHSECRET" backend.list -p | grep -e root)

BACKENDS=$(echo "$OUTPUT" | wc -l)
HEALTHY_BACKENDS=$(echo "$OUTPUT" | grep Healthy | wc -l)

if [ $HEALTHY_BACKENDS == 0 ]; then
	echo "$NAME CRITICAL: No healthy backends"
	exit 2
elif [ $HEALTHY_BACKENDS == 1 ]; then
	echo "$NAME WARNING: $HEALTHY_BACKENDS healthy of $BACKENDS backends"
	exit 1
else
	echo "$NAME OK: $HEALTHY_BACKENDS healthy of $BACKENDS backends"
fi
