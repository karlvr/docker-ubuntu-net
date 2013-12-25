#!/bin/sh

kill -15 `psql -A -t -c "SELECT procpid FROM pg_stat_activity WHERE (current_query = '<IDLE> in transaction' OR current_query = 'BEGIN') AND usename = 'letterboxd' AND (current_timestamp - query_start) > interval '10 seconds'"`
