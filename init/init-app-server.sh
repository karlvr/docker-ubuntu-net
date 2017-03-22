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
		SECURE_STATIC_URLS="https://s1.ltrbxd.com"
		;;
	app2)
		STATIC_URLS="http://bullitt.s2.ltrbxd.com http://up.s2.ltrbxd.com http://brick.s2.ltrbxd.com http://moon.s2.ltrbxd.com"
		SECURE_STATIC_URLS="https://s2.ltrbxd.com"
		;;
	app3)
		STATIC_URLS="http://tron.s3.ltrbxd.com http://solaris.s3.ltrbxd.com http://robocop.s3.ltrbxd.com http://notorious.s3.ltrbxd.com"
		SECURE_STATIC_URLS="https://s3.ltrbxd.com"
		;;
	app4)
		STATIC_URLS="http://commando.s4.ltrbxd.com http://alien.s4.ltrbxd.com http://drive.s4.ltrbxd.com http://wargames.s4.ltrbxd.com"
		SECURE_STATIC_URLS="https://s4.ltrbxd.com"
		;;
	*)
		echo "Unsupported hostname: $(hostname)"
		exit 1
		;;
esac

/bin/rm -f /etc/apache2/sites-available/letterboxd
/bin/ln -s /opt/letterboxd/etc/apache2/sites-available/*.conf /etc/apache2/sites-available/
/usr/sbin/a2ensite letterboxd
/usr/sbin/a2ensite boxdit
/usr/sbin/a2dissite 000-default
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

# RemoteIpValve
# This must be at the Engine level so it sits above the ErrorReportValve so it is in effect when error pages are rendered.
# Also it reflects characteristics of our deployment environment so it belongs in server.xml really!
sed -e '/<\/Engine>/ i\
<Valve className="org.apache.catalina.valves.RemoteIpValve" internalProxies="10\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}|127\\.0\\.0\\.1" remoteIpHeader="X-Forwarded-For" protocolHeader="X-Forwarded-Proto" />' \
	--in-place /srv/tomcat/letterboxd/conf/server.xml

# Asset configuration
/bin/cp /opt/letterboxd/etc/tomcat/conf/letterboxd.xml /srv/tomcat/letterboxd/conf/Catalina/localhost/ROOT.xml
# NB. SECURE_STATIC_URLS is a prefix of STATIC_URLS so it must be replaced first!
/bin/sed -e "s|SECURE_STATIC_URLS|$SECURE_STATIC_URLS|" --in-place /srv/tomcat/letterboxd/conf/Catalina/localhost/ROOT.xml
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

# Apache
if [ -d /etc/apache2/conf-available ]; then
	cat > /etc/apache2/conf-available/letterboxd.conf <<EOF
# Allow serving of Letterboxd bundled web content
<Directory /opt/letterboxd/www/>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
</Directory>
EOF
	/usr/sbin/a2enconf letterboxd
fi

# Sensu
mkdir -p /etc/sensu/conf.d
ln -s /opt/letterboxd/etc/sensu/conf.d/check_websites.json /etc/sensu/conf.d/check_websites.json
