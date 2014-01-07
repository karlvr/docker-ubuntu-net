#!/bin/bash
#
# Install New Relic Server Monitoring

if [ -d /etc/newrelic ]; then
	echo "/etc/newrelic already exists"
	exit 1
fi

if [ ! -f /etc/apt/sources.list.d/newrelic.list ]; then
	echo deb http://apt.newrelic.com/debian/ newrelic non-free >> /etc/apt/sources.list.d/newrelic.list && \
	wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -
fi

apt-get update && \
apt-get install newrelic-sysmond && \
nrsysmond-config --set license_key=cecc70df07802265f62e0cd98833cb83e373b411 && \
/etc/init.d/newrelic-sysmond start
