#!/bin/bash
# Start a local Varnish server with the Letterboxd configuration

VARNISHD=/usr/local/opt/varnish/sbin/varnishd
INSTANCE_NAME=/usr/local/var/varnish
USER=$(id -un)

ROOT_VCL=$1
if [ "x$ROOT_VCL" == "x" ]; then
	ROOT_VCL=charles
fi

VCL_DIR=$(pwd)/$(dirname $0)/../etc/varnish
CONFIG=$VCL_DIR/${ROOT_VCL}.vcl

VARNISH_ADMIN_PORT=2000
VARNISH_PORT=8081

sudo $VARNISHD -F -n "$INSTANCE_NAME" -f "$CONFIG" -s malloc,1G -T 127.0.0.1:$VARNISH_ADMIN_PORT -a 0.0.0.0:$VARNISH_PORT \
	-p feature=+esi_disable_xml_check \
	-p feature=+esi_ignore_other_elements \
	-p workspace_client=256K \
	-p vcl_dir="$VCL_DIR"
