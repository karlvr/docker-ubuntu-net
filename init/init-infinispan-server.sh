#!/bin/bash

if [ -f /etc/default/orac-init ]; then
	. /etc/default/orac-init
fi

source /opt/orac/init/functions.sh

INFINISPAN_VERSION=8.2.7.Final

gate infinispan "Installing Infinispan"
if [ $? == 0 ]; then
	check_not_directory /opt/infinispan-server-$INFINISPAN_VERSION
	if [ $? == 0 ]; then
		mkdir -p /opt/src
		wget --no-verbose http://downloads.jboss.org/infinispan/$INFINISPAN_VERSION/infinispan-server-$INFINISPAN_VERSION-bin.zip -O /opt/src/infinispan-server-$INFINISPAN_VERSION-bin.zip && \
		unzip -q -d /opt /opt/src/infinispan-server-$INFINISPAN_VERSION-bin.zip && \
		rm -f /opt/infinispan && \
		ln -s /opt/infinispan-server-$INFINISPAN_VERSION /opt/infinispan && \
		chmod -R u=rwX,go=rX /opt/infinispan/
		assert_success "Failed to download and extract Infinispan"

		# PostgreSQL
		mkdir -p /opt/infinispan/modules/org/postgresql/main
		wget --no-verbose http://jdbc.postgresql.org/download/postgresql-9.4-1201.jdbc41.jar -P /opt/infinispan/modules/org/postgresql/main
		cat <<EOF > /opt/infinispan/modules/org/postgresql/main/module.xml
<?xml version="1.0" encoding="UTF-8"?>  
<module xmlns="urn:jboss:module:1.0" name="org.postgresql">  
	<resources>  
		<resource-root path="postgresql-9.4-1201.jdbc41.jar"/>  
	</resources>  
	<dependencies>  
		<module name="javax.api"/>  
		<module name="javax.transaction.api"/>  
	</dependencies>  
</module>
EOF

		# Patch jgroups to add the PostgreSQL dependency for JDBC_PING
		patch -u -f -d /opt/infinispan modules/system/layers/base/org/jgroups/main/module.xml <<EOF
--- module.xml	2015-02-20 11:30:36.000000000 +1300
+++ module.new.xml	2015-04-08 08:50:18.308742564 +1200
@@ -33,5 +33,6 @@
         <module name="javax.api"/>
         <module name="org.jboss.as.clustering.jgroups"/>
         <module name="org.jboss.sasl" services="import" />
+        <module name="org.postgresql" />
     </dependencies>
 </module>
EOF
		
		# Configuration
		ln -s /opt/letterboxd/etc/infinispan/standalone/configuration/letterboxd.xml /opt/infinispan/standalone/configuration/
	fi

	# Infinispan user
	useradd -d /opt/infinispan -s /bin/bash infinispan
	chown -R infinispan /opt/infinispan/

	# Infinispan service
	mkdir -p /etc/infinispan-server && \
	rm -f /etc/infinispan-server/infinispan-server.conf && \
	ln -s /opt/letterboxd/etc/infinispan/bin/init.d/infinispan-server.conf /etc/infinispan-server/infinispan-server.conf

	rm -f /etc/init.d/infinispan && \
	ln -s /opt/infinispan/bin/init.d/infinispan-server-lsb.sh /etc/init.d/infinispan && \
	update-rc.d infinispan defaults 99 00
	warn_failure "Failed to create infinispan service"

	announce_end
fi
