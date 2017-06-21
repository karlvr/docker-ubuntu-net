#!/bin/bash -eu
# Varnish server

# NB: this script is incomplete

# nginx

apt-get install nginx
ln -s /opt/letterboxd/etc/nginx/varnish.conf /etc/nginx/conf.d/
ln -s /opt/letterboxd/etc/nginx/sites-available/* /etc/nginx/sites-enabled/
