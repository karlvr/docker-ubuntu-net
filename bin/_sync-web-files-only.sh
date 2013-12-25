#!/bin/bash
# 
# Syncs the Letterboxd web root to application servers
# usage: sync-server.sh <server>+

ssh-add

for SERVER in $*
do
echo "Syncing web root..."
rsync -av --stats  --delete /srv/www/letterboxd/web $SERVER:/srv/www/letterboxd
done
