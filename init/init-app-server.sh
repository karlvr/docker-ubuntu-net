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
