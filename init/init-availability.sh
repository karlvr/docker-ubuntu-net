#!/bin/bash -eu
#
# Init availability

BASEDIR=$(dirname $0)/..

cp "$BASEDIR"/etc/cron.d/letterboxd-availability /etc/cron.d

useradd -s /bin/bash availability
mkdir -p /home/availability
chown availability.availability /home/availability
