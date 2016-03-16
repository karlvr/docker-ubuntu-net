# Letterboxd

## App Server

First run the Orac Scripts init process:
```
/opt/orac/init/init-hostname.sh <hostname>
/opt/orac/init/init-ssh.sh
/opt/orac/init/init-base.sh
dpkg-reconfigure exim4-config
/opt/orac/init/init-mandrill.sh
/opt/orac/init/init-security.sh
/opt/orac/init/init-java.sh
/opt/orac/init/init-apache.sh
/opt/orac/init/init-tomcat.sh
/opt/orac/init/init-monitoring.sh
```

Run `init-server.sh` to setup the common Letterboxd server settings.

Ensure that `init-app-server.sh` has support for the new app server hostname (see near the top of the file), then
run `init-app-server.sh`
