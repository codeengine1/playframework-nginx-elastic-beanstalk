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


cat > /opt/elasticbeanstalk/tasks/taillogs.d/tomcat7.conf <<EOLTAILLOG
/var/log/tomcat7/*.out
/var/log/tomcat7/*.log
/var/log/tomcat7/*.txt
EOLTAILLOG

cat > /opt/elasticbeanstalk/tasks/taillogs.d/httpd.conf <<EOLTAILLOG
/var/log/httpd/*log
EOLTAILLOG


cat > /opt/elasticbeanstalk/tasks/systemtaillogs.d/tomcat7.conf <<EOLSYSTAILLOG
/var/log/tomcat7/*.out
/var/log/tomcat7/*.log
/var/log/tomcat7/*.txt
EOLSYSTAILLOG

cat > /opt/elasticbeanstalk/tasks/systemtaillogs.d/httpd.conf <<EOLSYSTAILLOG
/var/log/httpd/*log
EOLSYSTAILLOG


cat > /opt/elasticbeanstalk/tasks/bundlelogs.d/tomcat7.conf <<EOLBUNDLELOG
/var/log/tomcat7/*
EOLBUNDLELOG

cat > /opt/elasticbeanstalk/tasks/bundlelogs.d/httpd.conf <<EOLBUNDLELOG
/var/log/httpd/*
EOLBUNDLELOG


cat > /opt/elasticbeanstalk/tasks/publishlogs.d/tomcat7.conf <<EOLPUBLOG
/var/log/tomcat7/*.gz
EOLPUBLOG

cat > /opt/elasticbeanstalk/tasks/publishlogs.d/httpd.conf <<EOLPUBLOG
/var/log/httpd/*.gz
EOLPUBLOG


echo "Removing tomcat internal log rotation."
/bin/sed -i -e 's|prefix="localhost_access_log.*$|prefix="localhost_access_log" suffix=".txt" rotatable="false"|' /etc/tomcat7/server.xml


# Tomcat logging
cat > /etc/logrotate.conf.elasticbeanstalk <<EOLOGROTATE
/var/log/tomcat7/catalina.out /var/log/tomcat7/localhost_access_log.txt {
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

echo "Removing default tomcat logrotate."
/bin/rm -f /etc/logrotate.d/tomcat7

echo "Removing default httpd logrotate."
/bin/rm -f /etc/logrotate.d/httpd

echo "Removing extra log file."
sed -i '/.handlers = 1catalina.org.apache.juli.FileHandler, java.util.logging.ConsoleHandle/c \
.handlers = java.util.logging.ConsoleHandler' /etc/tomcat7/logging.properties
sed -i '/org.apache.catalina.core.ContainerBase.\[Catalina\].\[localhost\].handlers = 2localhost.org.apache.juli.FileHandler/c \
org.apache.catalina.core.ContainerBase.[Catalina].[localhost].handlers = java.util.logging.ConsoleHandler' /etc/tomcat7/logging.properties
