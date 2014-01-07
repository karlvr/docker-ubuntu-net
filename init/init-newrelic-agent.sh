#!/bin/bash
#
# Install New Relic Java Agent

if [[ $HOME != /srv/tomcat/* ]]; then
	echo "Please run this script as the Tomcat user you want to install New Relic into"
	exit 1
fi

if [ -d "$HOME/newrelic" ]; then
	echo "$HOME/newrelic already exists"
	exit 1
fi

mkdir "$HOME/newrelic"
ln -s /opt/letterboxd/etc/newrelic/* "$HOME/newrelic/"

cat >> "$HOME/.bash_profile" <<"EOF"
export JAVA_OPTS="$JAVA_OPTS -javaagent:$HOME/newrelic/newrelic.jar"
EOF
