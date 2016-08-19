#!/bin/bash
#
# GoWatchIt update script

if [ $(id -un) != "availability" ]; then
	echo "This script must be run as availability user"
	exit 1
fi

ONLY_SPECIFIED_MODES=0
DO_DOWNLOAD=0
DO_UPDATE=0

while getopts ":ud" opt; do
  case $opt in
    u)
      ONLY_SPECIFIED_MODES=1
      DO_UPDATE=1
      ;;
    d)
      ONLY_SPECIFIED_MODES=1
      DO_DOWNLOAD=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

TMPDIRNAME=gwi
. $(dirname $0)/../libexec/tool-base.sh

JAVA_OPTS="-Xmx2048M"
#JAVA_OPTS="$JAVA_OPTS -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode"
JAVA_OPTS="$JAVA_OPTS -Djava.io.tmpdir="$TMPDIR" -cp $CP"
if [ $DEV == 0 ]; then
	JAVA_OPTS="$JAVA_OPTS -Dletterboxd.live=true"
fi

if [ $ONLY_SPECIFIED_MODES == 0 -o $DO_DOWNLOAD == 1 ]; then
	echo "*** Starting download ***"
	echo
	java $JAVA_OPTS com.letterboxd.tools.gwi.GoWatchItAvailabilityDownload 2>&1 | tee "$TMPDIR"/download.log
	if [ $? != 0 ]; then
		echo "Download failed"
		exit 1
	else
		echo
	fi
fi

if [ $ONLY_SPECIFIED_MODES == 0 -o $DO_UPDATE == 1 ]; then
	echo "*** Starting update ***"
	echo
	java $JAVA_OPTS com.letterboxd.tools.gwi.GoWatchItAvailabilityUpdate 2>&1 | tee "$TMPDIR"/update.log
fi
