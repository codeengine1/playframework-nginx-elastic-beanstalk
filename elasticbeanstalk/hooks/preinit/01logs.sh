#!/bin/bash
#==============================================================================
# Copyright 2012 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#       http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#==============================================================================


set -xe

mkdir -p /opt/elasticbeanstalk/tasks/bundlelogs.d
mkdir -p /opt/elasticbeanstalk/tasks/publishlogs.d
mkdir -p /opt/elasticbeanstalk/tasks/systemtaillogs.d
mkdir -p /opt/elasticbeanstalk/tasks/taillogs.d


cat > /opt/elasticbeanstalk/tasks/taillogs.d/play.conf <<EOLTAILLOG
/var/app/current/logs/*.log
EOLTAILLOG

cat > /opt/elasticbeanstalk/tasks/taillogs.d/httpd.conf <<EOLTAILLOG
/var/log/httpd/*log
EOLTAILLOG


cat > /opt/elasticbeanstalk/tasks/systemtaillogs.d/play.conf <<EOLSYSTAILLOG
/var/app/current/logs/*.log
EOLSYSTAILLOG

cat > /opt/elasticbeanstalk/tasks/systemtaillogs.d/httpd.conf <<EOLSYSTAILLOG
/var/log/httpd/*log
EOLSYSTAILLOG


cat > /opt/elasticbeanstalk/tasks/bundlelogs.d/play.conf <<EOLBUNDLELOG
/var/app/current/logs/*.log
EOLBUNDLELOG

cat > /opt/elasticbeanstalk/tasks/bundlelogs.d/httpd.conf <<EOLBUNDLELOG
/var/log/httpd/*
EOLBUNDLELOG


cat > /opt/elasticbeanstalk/tasks/publishlogs.d/play.conf <<EOLPUBLOG
/var/app/current/logs/*.gz
EOLPUBLOG

cat > /opt/elasticbeanstalk/tasks/publishlogs.d/httpd.conf <<EOLPUBLOG
/var/log/httpd/*.gz
EOLPUBLOG

# Tomcat logging
cat > /etc/logrotate.conf.elasticbeanstalk <<EOLOGROTATE
/var/app/current/logs/ {
    size 1M
    missingok
    rotate 5
    compress
    notifempty
    copytruncate
    dateext
    dateformat -%s
}
EOLOGROTATE

cat > /etc/logrotate.conf.elasticbeanstalk.httpd <<EOLOGROTATE2
/var/log/httpd/*log {
    size 100M
    missingok
    rotate 9
    compress
    notifempty
    dateext
    dateformat -%s
    sharedscripts
    delaycompress
    create 
    postrotate
        /sbin/service httpd reload > /dev/null 2>/dev/null || true
    endscript
}
EOLOGROTATE2

## Setup hourly cron to rotate logs
## Set -f so that these logs are rotated every time. 
cat > /etc/cron.hourly/logrotate-elasticbeanstalk <<EOLOGCRON
#!/bin/sh
test -x /usr/sbin/logrotate || exit 0
/usr/sbin/logrotate -f /etc/logrotate.conf.elasticbeanstalk
EOLOGCRON
chmod 755 /etc/cron.hourly/logrotate-elasticbeanstalk

## Setup hourly cron to rotate logs (do not set -f)
cat > /etc/cron.hourly/logrotate-elasticbeanstalk-httpd <<EOLOGCRON2
#!/bin/sh
test -x /usr/sbin/logrotate || exit 0
/usr/sbin/logrotate /etc/logrotate.conf.elasticbeanstalk.httpd
EOLOGCRON2
chmod 755 /etc/cron.hourly/logrotate-elasticbeanstalk-httpd

echo "Removing default httpd logrotate."
/bin/rm -f /etc/logrotate.d/httpd

