#!/bin/bash

if [ -f /etc/default/orac-init ]; then
	. /etc/default/orac-init
fi

source /opt/orac/init/functions.sh

INFINISPAN_VERSION=6.0.0.Final

gate infinispan "Installing Infinispan"
if [ $? == 0 ]; then
	check_not_directory /opt/infinispan-server-$INFINISPAN_VERSION
	if [ $? == 0 ]; then
		mkdir -p /opt/src
		wget --no-verbose http://downloads.jboss.org/infinispan/$INFINISPAN_VERSION/infinispan-server-$INFINISPAN_VERSION-bin.zip -O /opt/src/infinispan-server-$INFINISPAN_VERSION-bin.zip && \
		unzip -d /opt /opt/src/infinispan-server-$INFINISPAN_VERSION-bin.zip && \
		rm -f /opt/infinispan && \
		ln -s /opt/infinispan-server-$INFINISPAN_VERSION /opt/infinispan && \
		chmod -R u=rwX,go=rX /opt/infinispan/
		assert_success "Failed to download and extract Infinispan"

		# PostgreSQL
		mkdir -p /opt/infinispan/modules/org/postgresql/main
		wget --no-verbose http://jdbc.postgresql.org/download/postgresql-9.3-1100.jdbc41.jar -P /opt/infinispan/modules/org/postgresql/main
		cat <<EOF > /opt/infinispan/modules/org/postgresql/main/module.xml
<?xml version="1.0" encoding="UTF-8"?>  
<module xmlns="urn:jboss:module:1.0" name="org.postgresql">  
	<resources>  
		<resource-root path="postgresql-9.3-1100.jdbc41.jar"/>  
	</resources>  
	<dependencies>  
		<module name="javax.api"/>  
		<module name="javax.transaction.api"/>  
	</dependencies>  
</module>
EOF

		# Patch jgroups to add the PostgreSQL dependency for JDBC_PING
		patch -u -f -d /opt/infinispan modules/system/layers/base/org/jgroups/main/module.xml <<EOF
--- modules/system/layers/base/org/jgroups/main/module.xml	2013-12-26 13:34:20.000000000 +1300
+++ modules/system/layers/base/org/jgroups/main/module.new.xml	2013-12-26 12:33:18.000000000 +1300
@@ -32,5 +32,6 @@
     <dependencies>
         <module name="javax.api"/>
         <module name="org.jboss.as.clustering.jgroups"/>
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
	ln -s /opt/letterboxd/etc/infinispan/bin/init.d/infinispan-server.conf /etc/nfinispan-server/infinispan-server.conf

	rm -f /etc/init.d/infinispan && \
	ln -s /opt/letterboxd/etc/infinispan/bin/init.d/infinispan-server-lsb.sh /etc/init.d/infinispan && \
	update-rc.d infinispan defaults 99 00
	warn_failure "Failed to create infinispan service"

	announce_end
fi
