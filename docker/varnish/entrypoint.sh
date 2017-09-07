#!/bin/bash -eu

# Maximum number of open files (for ulimit -n)
NFILES=131072

# Maximum locked memory size (for ulimit -l)
# Used for locking the shared memory log in memory.  If you increase log size,
# you need to increase this number as well
MEMLOCK=82000

DAEMON_OPTS="-a :80 \
             -T 127.0.0.1:6082 \
             -f /etc/varnish/letterboxd.vcl \
             -S /etc/varnish/secret \
             -s malloc,256m \
             -p feature=+esi_disable_xml_check \
             -p feature=+esi_ignore_other_elements \
             -p workspace_client=768K \
             -p vcl_dir=/etc/varnish/"

varnishd ${DAEMON_OPTS}
varnishlog
