FROM jboss/infinispan-server:8.2.6.Final

COPY configuration/letterboxd.xml /opt/jboss/infinispan-server/standalone/configuration/
ADD https://jdbc.postgresql.org/download/postgresql-42.1.4.jar /opt/jboss/infinispan-server/modules/org/postgresql/main/
COPY postgres-module.xml /opt/jboss/infinispan-server/modules/org/postgresql/main/module.xml
COPY find-hostname /usr/local/bin/

RUN sed -e '/sasl/a         <module name="org.postgresql" />' --in-place /opt/jboss/infinispan-server/modules/system/layers/base/org/jgroups/main/module.xml

USER root
RUN yum install -y haproxy nc lsof
COPY haproxy.cfg /etc/haproxy/
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
#RUN sed -e '/^BIND=/a echo "BIND: $BIND"' --in-place /usr/local/bin/docker-entrypoint.sh
#RUN sed -e '/^#!/a echo "ARGS: $*"' --in-place /usr/local/bin/docker-entrypoint.sh
#RUN sed -e 's/BIND=.*/BIND=$(find-hostname)/' --in-place /usr/local/bin/docker-entrypoint.sh
#RUN sed -e '/BIND_OPTS=/a BIND_OPTS="$BIND_OPTS -Djboss.bind.address.hotrod=0.0.0.0"' --in-place /usr/local/bin/docker-entrypoint.sh
RUN chown jboss /opt/jboss/infinispan-server/modules/org/postgresql/main/*
USER jboss

EXPOSE 11224
