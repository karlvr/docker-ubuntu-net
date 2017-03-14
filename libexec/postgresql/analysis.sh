#!/bin/bash
#
# Database maintenance

if [ $(id -un) != "letterboxd" ]; then
	echo "This script must be run as letterboxd."
	exit 1
fi

# Person analysis
PGOPTIONS='--client-min-messages=warning' psql letterboxd -q -f /opt/letterboxd/lib/postgresql/personanalysis.sql -v ON_ERROR_STOP=1
