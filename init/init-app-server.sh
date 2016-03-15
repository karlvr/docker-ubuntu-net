#!/bin/bash
#
# Init application server

if [ ! -d /opt/tomcat ]; then
	echo "Please run /opt/orac/init/init-tomcat.sh first"
	exit 1
fi

case $(hostname) in
	app1)
		STATIC_URLS="http://elephant.s1.ltrbxd.com http://psycho.s1.ltrbxd.com http://predator.s1.ltrbxd.com http://memento.s1.ltrbxd.com"
		;;
	app2)
		STATIC_URLS="http://bullitt.s2.ltrbxd.com http://up.s2.ltrbxd.com http://brick.s2.ltrbxd.com http://moon.s2.ltrbxd.com"
		;;
	app3)
		STATIC_URLS="http://tron.s3.ltrbxd.com http://solaris.s3.ltrbxd.com http://robocop.s3.ltrbxd.com http://notorious.s3.ltrbxd.com"
		;;
	app4)
		STATIC_URLS="http://commando.s4.ltrbxd.com http://alien.s4.ltrbxd.com http://drive.s4.ltrbxd.com http://wargames.s4.ltrbxd.com"
		;;
	*)
		echo "Unsupported hostname: $(hostname)"
		exit 1
		;;
esac

/bin/rm -f /etc/apache2/sites-available/letterboxd
/bin/ln -s /opt/letterboxd/etc/apache2/sites-available/letterboxd.conf /etc/apache2/sites-available/letterboxd.conf
/usr/sbin/a2ensite letterboxd
/usr/sbin/a2enmod ssl

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
/bin/cp /opt/letterboxd/etc/tomcat/conf/letterboxd.xml /srv/tomcat/letterboxd/conf/Catalina/localhost/ROOT.xml
/bin/sed -e "s|STATIC_URLS|$STATIC_URLS|" --in-place /srv/tomcat/letterboxd/conf/Catalina/localhost/ROOT.xml

/bin/cp /opt/letterboxd/etc/tomcat/conf/staging.xml /srv/tomcat/staging/conf/Catalina/localhost/ROOT.xml

cat <<EOF > /srv/tomcat/letterboxd/.bash_profile
#!/bin/bash
#
# NB: this file is automatically created by the init-app-server.sh script

export JAVA_MAX_HEAP=10G
export JAVA_OPTS="-Xms5G -XX:ReservedCodeCacheSize=300M"

# Performance baseline for David Maplesden
#export JAVA_OPTS="$JAVA_OPTS -Xloggc:gc.log -verbose:gc"
EOF

cat <<EOF > /srv/tomcat/staging/.bash_profile
#!/bin/bash
#
# NB: this file is automatically created by the init-app-server.sh script

export JAVA_MAX_HEAP=6512M
EOF
