#!/bin/bash

if [ ! -d /etc/postgresql ]; then
	echo "Install PostgreSQL first"
	exit 1
fi

if [ ! -d /home/letterboxd ]; then
	useradd -m -d /home/letterboxd -s /bin/bash letterboxd
fi

# pgpool2 setup

apt-get install postgresql-9.3-pgpool2

su - postgres -c psql template1 <<EOF
CREATE EXTENSION pgpool_regclass; 
CREATE EXTENSION pgpool_recovery;
EOF
