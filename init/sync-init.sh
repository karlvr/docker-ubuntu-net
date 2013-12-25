#!/bin/bash
# Sync letterboxd scripts to remote server

if [ "x$1" == "x" ]; then
	echo "usage: $0 <server> [<server> ...]"
	exit 1
fi

USER=root

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
if [ "$USER" == "root" ]; then
	DEST=/opt/letterboxd
else
	DEST=letterboxd
fi

for SERVER in $* ; do
	rsync -a --exclude "**/.git*" --exclude "**/.DS_Store" --delete --delete-excluded "$DIR"/ $USER@$SERVER:$DEST
	echo "Synced $DIR to $USER@$SERVER:$DEST"
done
