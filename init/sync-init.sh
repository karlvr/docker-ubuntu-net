#!/bin/bash
# Sync letterboxd scripts to remote server

USER=root

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
if [ "$USER" == "root" ]; then
	DEST=/opt/letterboxd
else
	DEST=letterboxd
fi

SERVERS=$*
if [ "x$SERVERS" == "x" ]; then
	SERVERS="app1.letterboxd.com app2.letterboxd.com app3.letterboxd.com app4.letterboxd.com db1.letterboxd.com db2.letterboxd.com"
fi

for SERVER in $SERVERS ; do
	rsync -a --exclude "**/.git*" --exclude "**/.DS_Store" --delete --delete-excluded "$DIR"/ $USER@$SERVER:$DEST
	echo "Synced $DIR to $USER@$SERVER:$DEST"
done
