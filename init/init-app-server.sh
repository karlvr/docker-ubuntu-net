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

# Bind AJP to vlan address
# We use this when we're binding to the vlan interface for local load balancing
sed -e "s/<Connector port=\"20001\" address=\"127.0.0.1\"/<Connector port=\"20001\" address=\"$(hostname -i)\"/" --in-place /srv/tomcat/letterboxd/conf/server.xml

# JVM route
sed -e "s/<Engine name=\"Catalina\" defaultHost=\"localhost\">/<Engine name=\"Catalina\" defaultHost=\"localhost\" jvmRoute=\"$(hostname)\">/" --in-place /srv/tomcat/letterboxd/conf/server.xml

# Asset configuration
case $(hostname) in
	app1)
		STATIC_URLS="http://elephant.cf1.letterboxd.com http://psycho.cf1.letterboxd.com http://predator.cf1.letterboxd.com http://memento.cf1.letterboxd.com"
		;;
	app2)
		STATIC_URLS="http://bullitt.cf2.letterboxd.com http://up.cf2.letterboxd.com http://brick.cf2.letterboxd.com http://moon.cf2.letterboxd.com"
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

