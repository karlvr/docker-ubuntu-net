#FROM jboss/infinispan-server:8.2.6.Final
#FROM karlvr/infinispan-server:8.2.8.Final
FROM jboss/infinispan-server:9.1.0.Final

ADD https://jdbc.postgresql.org/download/postgresql-42.1.4.jar /opt/jboss/infinispan-server/modules/org/postgresql/main/
COPY postgres-module.xml /opt/jboss/infinispan-server/modules/org/postgresql/main/module.xml

RUN sed -e '/sasl/a         <module name="org.postgresql" />' --in-place /opt/jboss/infinispan-server/modules/system/layers/base/org/jgroups/main/module.xml

USER root
RUN yum install -y haproxy nc lsof
COPY haproxy.cfg /etc/haproxy/
COPY find-hostname /usr/local/bin/
COPY docker-entrypoint.sh /usr/local/bin/
RUN chown jboss /opt/jboss/infinispan-server/modules/org/postgresql/main/*
USER jboss

# Configuration layer is last as we change it frequently, and being last means only
# one layer needs to be pushed, usually.
COPY configuration/letterboxd.xml /opt/jboss/infinispan-server/standalone/configuration/

EXPOSE 11224
