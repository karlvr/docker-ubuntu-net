#!/bin/bash

VARNISHADM=varnishadm
VARNISHADDRESS=localhost:6082
VARNISHSECRET=/etc/varnish/secret-sensu
NAME=CheckVarnishBackends

check_varnish() {
	OUTPUT=$("$VARNISHADM" -T "$VARNISHADDRESS" -S "$VARNISHSECRET" backend.list -p | grep -e LB_)
}

check_varnish

if [ $? != 0 ]; then
	sleep 5
	check_varnish
	if [ $? != 0 ]; then
		echo "$NAME WARNING: $VARNISHADM failed"
		exit 1
	fi
fi

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
