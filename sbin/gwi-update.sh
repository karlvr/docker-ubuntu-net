#!/bin/bash
#
# GoWatchIt update script

if [ $(id -un) != "availability" ]; then
	echo "This script must be run as availability user"
	exit 1
fi

TMPDIRNAME=gwi
. $(dirname $0)/../libexec/tool-base.sh

JAVA_OPTS="-Xmx2048M"
#JAVA_OPTS="$JAVA_OPTS -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode"
JAVA_OPTS="$JAVA_OPTS -Djava.io.tmpdir="$TMPDIR" -cp $CP"
if [ $DEV == 0 ]; then
	JAVA_OPTS="$JAVA_OPTS -Dletterboxd.live=true"
fi

echo "*** Starting download ***"
echo
java $JAVA_OPTS com.letterboxd.tools.gwi.GoWatchItAvailabilityDownload 2>&1 | tee "$TMPDIR"/download.log

if [ $? == 0 ]; then
	echo
	echo "*** Starting update ***"
	echo
	java $JAVA_OPTS com.letterboxd.tools.gwi.GoWatchItAvailabilityUpdate 2>&1 | tee "$TMPDIR"/update.log
else
	echo "Not running update due to failure of download" >&2
fi
