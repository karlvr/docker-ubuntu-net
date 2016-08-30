#!/bin/bash

if [ ! -d /etc/postgresql ]; then
	echo "Install PostgreSQL first"
	exit 1
fi

if [ ! -d /home/letterboxd ]; then
	useradd -m -d /home/letterboxd -s /bin/bash letterboxd
fi
