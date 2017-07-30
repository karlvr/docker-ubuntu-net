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
	NAME=$1
	echo "$SCHEME.$NAME.$CACHE $VALUE $NOW"
}

handleOutput() {
	NOW=$(date +%s)

	echo "$OUTPUT" | while read LINE ; do
	 	KEY=$(echo $LINE | cut -d '=' -f 1)
	 	VALUE=$(echo $LINE | cut -d '=' -f 2)

	 	if [ "$KEY" == "number-of-entries" ]; then
	 		outputValue "entries"
	 	elif [ "$KEY" == "hit-ratio" ]; then
	 		outputValue "hitRatio"
	 	elif [ "$KEY" == "read-write-ratio" ]; then
	 		outputValue "readWriteRatio"
	 	elif [ "$KEY" == "evictions" ]; then
	 		outputValue "evictions"
	 	elif [ "$KEY" == "stores" ]; then
	 		outputValue "stores"
	 	elif [ "$KEY" == "time-since-reset" ]; then
	 		outputValue "timeSinceReset"
	 	elif [ "$KEY" == "time-since-start" ]; then
	 		outputValue "timeSinceStart"
	 	elif [ "$KEY" == "cluster-size" ]; then
	 		outputValue "clusterSize"
	 	elif [ "$KEY" == "number-of-locks-held" ]; then
	 		outputValue "locksHeld"
	 	elif [ "$KEY" == "replication-failures" ]; then
	 		outputValue "replicationFailures"
	 	elif [ "$KEY" == "success-ratio" ]; then
	 		outputValue "replicationSuccessRatio"
	 	elif [ "$KEY" == "cluster-hit-ratio" ]; then
	 		outputValue "clusterHitRatio"
	 	elif [ "$KEY" == "cluster-read-write-ratio" ]; then
	 		outputValue "custerReadWriteRatio"
	 	fi
	done
}

# Tidy up any hung ispn-cli.sh commands
ps x | grep java | grep infinispan | xargs kill -9

OUTPUT=$(/opt/infinispan/bin/ispn-cli.sh --connect "container clustered82,ls")
CACHE=all
handleOutput

CACHES=$(/opt/infinispan/bin/ispn-cli.sh --connect "container clustered82,ls distributed-cache")

for RAW_CACHE in $CACHES ; do
	CACHE=${RAW_CACHE/./_}
	OUTPUT=$(/opt/infinispan/bin/ispn-cli.sh --connect "container clustered82,ls distributed-cache=$RAW_CACHE")
	
	handleOutput
done
