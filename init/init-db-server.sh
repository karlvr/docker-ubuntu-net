#!/bin/bash

if [ ! -d /etc/postgresql ]; then
	echo "Install PostgreSQL first"
	exit 1
fi

if [ ! -d /home/letterboxd ]; then
	useradd -m -d /home/letterboxd -s /bin/bash letterboxd
fi

###############################################################################
# performance

# dirty_background_bytes: https://blog.2ndquadrant.com/basics-of-tuning-checkpoints/
#   and https://github.com/grayhemp/pgcookbook/blob/master/database_server_configuration.md
#   and https://lonesysadmin.net/2013/12/22/better-linux-disk-caching-performance-vm-dirty_ratio/

# hugepages: https://www.postgresql.org/docs/9.5/static/kernel-resources.html
#   4350 comes from production database server:
#     grep ^VmPeak /proc/5210/status
#     VmPeak:	 8845284 kB
#     grep ^Hugepagesize /proc/meminfo
#     Hugepagesize:       2048 kB
#   8845284 / 2048 = 4319 (rounded up to 4350)

# kernel scheduler: https://www.postgresql.org/message-id/50E4AAB1.9040902@optionshouse.com
#   and https://www.percona.com/live/plam16/sites/default/files/slides/pl_2016_kosmodemiansky_0.pdf

cat > /etc/sysctl.d/99-letterboxd-postgres.conf <<EOF
vm.dirty_background_bytes=8388608
vm.nr_hugepages=4350
vm.hugetlb_shm_group=$(id -g postgres)
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=0
EOF


###############################################################################
# pgbouncer
apt-get install pgbouncer

service pgbouncer stop

patch /etc/pgbouncer/pgbouncer.ini <<EOF
--- /tmp/pgbouncer.ini	2017-06-21 11:12:28.513371306 +1200
+++ /etc/pgbouncer/pgbouncer.ini	2017-06-21 11:20:59.061635569 +1200
@@ -5,6 +5,7 @@
 ;;   client_encoding= datestyle= timezone=
 ;;   pool_size= connect_query=
 [databases]
+letterboxd = host=db1 port=5432 dbname=letterboxd
 
 ; foodb over unix socket
 ;foodb =
@@ -36,7 +37,7 @@
 ;;;
 
 ; ip address or * which means all ip-s
-listen_addr = 127.0.0.1
+listen_addr = *
 listen_port = 6432
 
 ; unix socket is also used for -R.
@@ -51,7 +52,7 @@
 ;;;
 
 ;; disable, allow, require, verify-ca, verify-full
-;client_tls_sslmode = disable
+client_tls_sslmode = require
 
 ;; Path to file that contains trusted CA certs
 ;client_tls_ca_file = <system default>
@@ -60,6 +61,8 @@
 ;; Required for accepting TLS connections from clients.
 ;client_tls_key_file =
 ;client_tls_cert_file =
+client_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
+client_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
 
 ;; fast, normal, secure, legacy, <ciphersuite string>
 ;client_tls_ciphers = fast
@@ -78,7 +81,7 @@
 ;;;
 
 ;; disable, allow, require, verify-ca, verify-full
-;server_tls_sslmode = disable
+server_tls_sslmode = require
 
 ;; Path to that contains trusted CA certs
 ;server_tls_ca_file = <system default>
@@ -99,7 +102,7 @@
 ;;;
 
 ; any, trust, plain, crypt, md5
-auth_type = trust
+auth_type = md5
 ;auth_file = /8.0/main/global/pg_auth
 auth_file = /etc/pgbouncer/userlist.txt
 
@@ -119,6 +122,7 @@
 
 ; comma-separated list of users who are just allowed to use SHOW command
 ;stats_users = stats, root
+stats_users = pgbouncer
 
 ;;;
 ;;; Pooler personality questions
@@ -155,7 +159,7 @@
 ; in startup packet.  Newer JDBC versions require the
 ; extra_float_digits here.
 ;
-;ignore_startup_parameters = extra_float_digits
+ignore_startup_parameters = extra_float_digits
 
 ;
 ; When taking idle server into use, this query is ran first.
@@ -175,12 +179,12 @@
 ;;;
 
 ; total number of clients that can connect
-max_client_conn = 100
+max_client_conn = 200
 
 ; default pool size.  20 is good number when transaction pooling
 ; is in use, in session pooling it needs to be the number of
 ; max clients you want to handle at any moment
-default_pool_size = 20
+default_pool_size = 200
 
 ;; Minimum number of server connections to keep in pool.
 ;min_pool_size = 0
EOF

cat > /etc/pgbouncer/userlist.txt <<EOF
"letterboxd" "x44zpyj6"
EOF

service pgbouncer start

# Check pgbouncer status:
# su - postgres -c 'psql -p 6432 pgbouncer pgbouncer'
# show stats;
# show clients;
