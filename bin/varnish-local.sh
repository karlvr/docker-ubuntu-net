#!/bin/bash
# Start a local Varnish server with the Letterboxd configuration
#
# Install varnish using Homebrew: `brew install varnish`
# Homebrew may not have the latest version. To ensure you run the same version as the live
# environment, use `brew edit varnish` and change the version number on the source file,
# delete the bottle URLs, run `brew install varnish` or `brew upgrade`, it should complain
# about the SHA hash, brew edit again to update the hash to what it said it needed then run
# again.

VARNISHD=/usr/local/opt/varnish/sbin/varnishd
VARNISH_VERSION=4.1.4

if [ ! -x $VARNISHD ]; then
	echo "FATAL: varnishd not found, is it installed?"
	echo
	echo "Install using Homebrew. See comments at the top of this file for more instructions."
	exit 1
fi

# Version check
$VARNISHD -V 2>&1 | grep "$VARNISH_VERSION" >/dev/null
if [ $? != 0 ]; then
	echo "FATAL: Incorrect varnishd version detected."
	echo "Required: $VARNISH_VERSION"
	echo -n "Actual: "
	$VARNISHD -V
	exit 1
fi

# VMODS
VMODS_DIR=/usr/local/lib/varnish/vmods
VMODS_SRC_DIR=$(dirname $0)/../lib/varnish/vmods-macosx
rsync -a "$VMODS_SRC_DIR"/* "$VMODS_DIR"/


INSTANCE_NAME=/usr/local/var/varnish
USER=$(id -un)

ROOT_VCL=$1
if [ "x$ROOT_VCL" == "x" ]; then
	ROOT_VCL=charles
fi

echo "Running with root VCL: $ROOT_VCL"

VCL_DIR=$(pwd)/$(dirname $0)/../etc/varnish
CONFIG=$VCL_DIR/${ROOT_VCL}.vcl

echo
echo "VCL: $CONFIG"

VARNISH_ADMIN_PORT=2000
VARNISH_PORT=8081
HITCH_PORT=8444

echo "Starting varnishd on port $VARNISH_PORT"
echo "Browse to http://$(hostname):$VARNISH_PORT/letterboxd/"

sudo $VARNISHD -F -n "$INSTANCE_NAME" -f "$CONFIG" -s malloc,1G -T 127.0.0.1:$VARNISH_ADMIN_PORT -a :$VARNISH_PORT -a :$HITCH_PORT,PROXY \
	-p feature=+esi_disable_xml_check \
	-p feature=+esi_ignore_other_elements \
	-p workspace_client=256K \
	-p vcl_dir="$VCL_DIR"
