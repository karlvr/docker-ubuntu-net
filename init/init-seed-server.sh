#!/bin/bash
#
# Initialise the seed server that we copy the rest of the config from

if [ -f /etc/default/orac-init ]; then
	. /etc/default/orac-init
fi

source /opt/orac/init/functions.sh

if [ ! -d /etc/shorewall ]; then
	echo "Please run /opt/orac/init/init-security.sh script first"
	exit 1
fi

gate shorewall "Configuring shorewall"
if [ $? == 0 ]; then
	rm -f /etc/shorewall/hosts
	rm -f /etc/shorewall/interfaces
	rm -f /etc/shorewall/policy
	rm -f /etc/shorewall/rules
	rm -f /etc/shorewall/zones

	ln -s /opt/letterboxd/etc/shorewall/* /etc/shorewall
fi
