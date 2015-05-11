#!/bin/bash

DEV=0
CONTINUE=0

while getopts ":dc" opt; do
  case $opt in
    d)
      DEV=1
      ;;
    c)
	  CONTINUE=1
	  ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

shift $((OPTIND-1))

if [ $DEV == 0 -a $(id -un) != "letterboxd" ]; then
	echo "This script must be run as letterboxd"
	exit 1
fi

if [ $DEV == 0 ]; then
	TOOLSJAR=/srv/tools/letterboxd-tools-1.0-SNAPSHOT-jar-with-dependencies.jar
	TMPDIR=/tmp/$TMPDIRNAME/tmp
	TOMCATLIBDIR=/opt/tomcat/lib
else
	TOOLSJAR=~/Development/let0596_letterboxd/tools/tools/target/letterboxd-tools-1.0-SNAPSHOT-jar-with-dependencies.jar
	TMPDIR=~/tmp/$TMPDIRNAME
	TOMCATLIBDIR=~/Library/Tomcat/Current/lib
fi

mkdir -p "$TMPDIR"

CP=$TOOLSJAR:`ls $TOMCATLIBDIR/*.jar | xargs echo | sed -e 's/ /:/g'`
