#!/bin/bash

useradd --create-home --home /home/pganalyze pganalyze --shell /bin/bash

pganalyze-collector --generate-config --config=/home/pganalyze/.pganalyze_collector.conf --api-key 77f8eb7e468d4f72fa17
chown pganalyze.pganalyze /home/pganalyze/.pganalyze_collector.conf
