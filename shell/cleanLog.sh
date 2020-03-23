#!/bin/bash
#

# clear cloudera manager monitor log
rm -rf /var/lib/cloudera-host-monitor/ts/*/partition*/*
rm -rf /var/lib/cloudera-service-monitor/ts/*/partition*/*

# clear cdh log
rm -rf /var/log/cloudera-scm-eventserver/*.out.*
rm -rf /var/log/cloudera-scm-firehose/*.out.*
rm -rf /var/log/cloudera-scm-agent/*.log.*
rm -rf /var/log/cloudera-scm-agent/*.out.*
rm -rf /var/log/cloudera-scm-server/*.out.*
rm -rf /var/log/cloudera-scm-server/*.log.*

rm -rf /var/log/hadoop-hdfs/*.out.*
rm -rf /var/log/hadoop-httpfs/*.out.*
rm -rf /var/log/hadoop-kms/*.out.*
rm -rf /var/log/hadoop-mapreduce/*.out.*

rm -rf /var/log/zookeeper/*.log.*
