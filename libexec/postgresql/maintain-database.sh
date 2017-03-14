#!/bin/bash
#
# Database maintenance

if [ $(id -un) != "letterboxd" ]; then
	echo "This script must be run as letterboxd."
	exit 1
fi

# Delete account activity that is more than 30 days old
psql letterboxd -q -c "delete from accountactivity where whenCreated < ('now'::date - 30);"
vacuumdb --table=accountactivity -z -v letterboxd

# Fix broken lists
psql letterboxd -q -c "select fixfilmlists()"
