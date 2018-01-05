#!/bin/bash

SCHEME="$(hostname).infinispan"

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
	local raw_cache="${1:-all}"
	local name="$2"
	local value="$3"

	local now=$(date +%s)
	local cache=${raw_cache/./_}

	echo "$SCHEME.$name.$cache $value $now"
}

readAttribute() {
	local attribute="$1"
	local raw_cache="${2:-}"

	#echo "Reading attribute $attribute from cache $raw_cache" >&2

	if [ ! -z "$raw_cache" ]; then
		value=$(/opt/infinispan/bin/ispn-cli.sh --connect "container $container,read-attribute --node=distributed-cache=$raw_cache $attribute")
	else
		value=$(/opt/infinispan/bin/ispn-cli.sh --connect "container $container,read-attribute $attribute")
	fi

	echo "$value" | sed 's/L$//'
}

outputValues() {
	local raw_cache="$1"

	outputValue "$raw_cache" "entries" "$(readAttribute number-of-entries "$raw_cache")" "$now"
	outputValue "$raw_cache" "hitRatio" "$(readAttribute hit-ratio "$raw_cache")" "$now"
	outputValue "$raw_cache" "readWriteRatio" "$(readAttribute read-write-ratio "$raw_cache")" "$now"
	outputValue "$raw_cache" "evictions" "$(readAttribute evictions "$raw_cache")" "$now"
	outputValue "$raw_cache" "stores" "$(readAttribute stores "$raw_cache")" "$now"
	outputValue "$raw_cache" "timeSinceReset" "$(readAttribute time-since-reset "$raw_cache")" "$now"
	outputValue "$raw_cache" "timeSinceStart" "$(readAttribute time-since-start "$raw_cache")" "$now"
	if [ -z "$raw_cache" ]; then
		outputValue "$raw_cache" "clusterSize" "$(readAttribute cluster-size "$raw_cache")" "$now"
	else
		outputValue "$raw_cache" "locksHeld" "$(readAttribute number-of-locks-held "$raw_cache")" "$now"
		outputValue "$raw_cache" "replicationFailures" "$(readAttribute replication-failures "$raw_cache")" "$now"
		outputValue "$raw_cache" "replicationSuccessRatio" "$(readAttribute success-ratio "$raw_cache")" "$now"
		#outputValue "$raw_cache" "clusterHitRatio" "$(readAttribute cluster-hit-ratio "$raw_cache")" "$now"
		#outputValue "$raw_cache" "custerReadWriteRatio" "$(readAttribute cluster-read-write-ratio "$raw_cache")" "$now"
	fi
}

# Tidy up any hung ispn-cli.sh commands
#ps x | grep java | grep infinispan | awk '{print $1}' | xargs kill -9

container=clustered

outputValues

caches=$(/opt/infinispan/bin/ispn-cli.sh --connect "container clustered,ls distributed-cache")

for raw_cache in $caches ; do
	outputValues "$raw_cache"
done
