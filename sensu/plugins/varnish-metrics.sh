#!/bin/bash

SCHEME="$(hostname).varnish"

while getopts ":s:" opt; do
  case $opt in
    s)
      SCHEME="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

outputValue() {
	local name="$1"
	local value="$2"
	local now=$(date +%s)

	echo "$SCHEME.$name $value $now"
}

VARNISHADM=varnishadm
VARNISHADDRESS=localhost:6082
VARNISHSECRET=/etc/varnish/secret-sensu

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

outputValue "healthy_backends" "$HEALTHY_BACKENDS"
outputValue "backends" "$BACKENDS"
