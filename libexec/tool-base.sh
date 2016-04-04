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

TMPDIR=

if [ $DEV == 0 ]; then
	TOOLSJAR=/srv/tools/letterboxd-tools-1.0-SNAPSHOT-jar-with-dependencies.jar
	if [ "x$HOME" != "x" -a "x$TMPDIRNAME" != "x" ]; then
		TMPDIR="$HOME"/work/"$TMPDIRNAME"
	elif [ "x$TMPDIRNAME" != "x" ]; then
		TMPDIR=/tmp/$TMPDIRNAME/tmp
	fi
	TOMCATLIBDIR=/opt/tomcat/lib
else
	TOOLSJAR=~/Development/let0596_letterboxd/tools/tools/target/letterboxd-tools-1.0-SNAPSHOT-jar-with-dependencies.jar
	if [ "x$TMPDIRNAME" != "x" ]; then
		TMPDIR=~/tmp/$TMPDIRNAME
	fi
	TOMCATLIBDIR=~/Library/Tomcat/Current/lib
fi

if [ "x$TMPDIR" != "x" ]; then
	mkdir -p "$TMPDIR"
fi

CP=$TOOLSJAR:`ls $TOMCATLIBDIR/*.jar | xargs echo | sed -e 's/ /:/g'`
