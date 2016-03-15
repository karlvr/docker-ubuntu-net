# Letterboxd

## App Server

First run the Orac Scripts init process, installing Java, Apache, monitoring, no database, and possibly no backup.

Run `init-server.sh` to setup the common Letterboxd server settings.

Ensure that `init-app-server.sh` has support for the new app server hostname (see near the top of the file), then
run `init-app-server.sh`

