#!/bin/bash
#
# Init application server

if [ ! -d /opt/tomcat ]; then
	echo "Please run /opt/orac/init/init-tomcat.sh first"
	exit 1
fi

/bin/rm -f /etc/apache2/sites-available/letterboxd
/bin/ln -s /opt/letterboxd/etc/apache2/sites-available/letterboxd /etc/apache2/sites-available/letterboxd
/usr/sbin/a2ensite letterboxd

/bin/rm -f /etc/apache2/workers.properties
/bin/ln -s /opt/letterboxd/etc/apache2/workers.properties /etc/apache2/workers.properties

/usr/sbin/apache2ctl configtest
/usr/sbin/apache2ctl graceful

/opt/orac/bin/init-tomcat letterboxd 20000 20001 dummy
/opt/orac/bin/init-tomcat staging 20002 20003 dummy

# Bind AJP to all interfaces
# We use this when we're binding to the vlan interface for local load balancing
# and for binding to the localhost interface so jk workers can connect to the local
# Tomcat with the same workers.properties on each machine.
sed -e "s/<Connector port=\"20001\" address=\"127.0.0.1\"/<Connector port=\"20001\"/" --in-place /srv/tomcat/letterboxd/conf/server.xml

# JVM route
sed -e "s/<Engine name=\"Catalina\" defaultHost=\"localhost\">/<Engine name=\"Catalina\" defaultHost=\"localhost\" jvmRoute=\"$(hostname)\">/" --in-place /srv/tomcat/letterboxd/conf/server.xml

# Asset configuration
case $(hostname) in
	app1)
		STATIC_URLS="http://elephant.s1.ltrbxd.com http://psycho.s1.ltrbxd.com http://predator.s1.ltrbxd.com http://memento.s1.ltrbxd.com"
		;;
	app2)
		STATIC_URLS="http://bullitt.s2.ltrbxd.com http://up.s2.ltrbxd.com http://brick.s2.ltrbxd.com http://moon.s2.ltrbxd.com"
		;;
	*)
		echo "Unsupported hostname: $(hostname)"
		exit 1
		;;
esac

/bin/cp /opt/letterboxd/etc/tomcat/conf/letterboxd.xml /srv/tomcat/letterboxd/conf/Catalina/localhost/ROOT.xml
/bin/sed -e "s|STATIC_URLS|$STATIC_URLS|" --in-place /srv/tomcat/letterboxd/conf/Catalina/localhost/ROOT.xml

/bin/cp /opt/letterboxd/etc/tomcat/conf/staging.xml /srv/tomcat/staging/conf/Catalina/localhost/ROOT.xml

cat <<EOF > /srv/tomcat/letterboxd/.bash_profile
#!/bin/bash
export JAVA_MAX_HEAP=10G
export JAVA_OPTS="-XX:PermSize=256M -XX:MaxPermSize=256M -verbose:gc -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode"
EOF

cat <<EOF > /srv/tomcat/staging/.bash_profile
#!/bin/bash
export JAVA_MAX_HEAP=6512M
export JAVA_OPTS="-XX:PermSize=256M -XX:MaxPermSize=256M -verbose:gc -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalMode"
EOF

# pgpool2

CODENAME=`lsb_release -c -s`
cat <<EOF > /etc/apt/sources.list.d/pgdg.list
deb http://apt.postgresql.org/pub/repos/apt/ $CODENAME-pgdg main
EOF
wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -
apt-get update

apt-get install pgpool2

# We install postgresql client so we can test connectivity
apt-get install postgresql-client-9.3
