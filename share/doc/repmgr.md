# repmgr

https://github.com/2ndQuadrant/repmgr

```
apt-get install -y postgresql-9.5-repmgr

createuser -s repmgr
createdb repmgr -O repmgr

postgres_version=9.5
```

## `pg_hba.conf`

NOTE! These entries must be before our existing remote entries, otherwise a password
will be prompted for, even though not required. This will confuse repmgr with an error
like:

```
fe_sendauth: no password supplied
```

```
cat >> /etc/postgresql/$postgres_version/main/pg_hba.conf <<EOF

local   replication   repmgr                              trust
hostssl replication   repmgr      127.0.0.1/32            trust
hostssl replication   repmgr      10.100.10.0/24          trust

local   repmgr        repmgr                              trust
hostssl repmgr        repmgr      127.0.0.1/32            trust
hostssl repmgr        repmgr      10.100.10.0/24          trust
EOF
```

## `postgresql.conf`

Must add the following to postgresql.conf:

```
shared_preload_libraries = 'repmgr_funcs'
max_wal_senders = 5
max_replication_slots = 5
wal_level = 'hot_standby'
hot_standby = 'on'
```

PostgreSQL must be restarted after making these changes.

## `repmgr.conf`

On the master (db1):

```
cat > /etc/repmgr.conf <<EOF
cluster=letterboxd
node=1
node_name=db1
conninfo='host=db1 user=repmgr dbname=repmgr'
use_replication_slots=1
pg_basebackup_options='--progress --xlog-method=stream'
pg_bindir=/usr/lib/postgresql/9.5/bin
EOF
```

And on the slave (db2):

```
cat > /etc/repmgr.conf <<EOF
cluster=letterboxd
node=2
node_name=db2
conninfo='host=db2 user=repmgr dbname=repmgr'
use_replication_slots=1
pg_basebackup_options='--progress --xlog-method=stream'
pg_bindir=/usr/lib/postgresql/9.5/bin
EOF
```

## Setup

On the master, become the `postgres` user:

```
psql -c 'ALTER USER repmgr SET search_path TO repmgr_letterboxd, "$user", public;'
```

Then register the master and check that the PostgreSQL configuration is correct.

```
repmgr master register
repmgr -h db1 -U repmgr -d repmgr --check-upstream-config
```

# On standby, as postgres:
repmgr -h db1 -U repmgr -d repmgr standby clone
repmgr standby register

# Check repmgr status:
psql -h db1 repmgr repmgr -c "select * from repl_nodes"

## Recovery

Say db1 dies, then you need to promote db2 to master.

On db2, as postgres:

```
repmgr standby promote
```

Then update pgbouncer to point to db2 and reload it.

Once the original master (db1) recovers, you need to set it up as a new slave:

On db1, as postgres:

```
repmgr -h db2 -U repmgr -d repmgr standby clone
pg_ctlcluster 9.5 main start
repmgr standby register -F
```
