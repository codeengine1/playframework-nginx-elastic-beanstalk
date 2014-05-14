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

function preinit() {
TOMCAT7_HOME=/usr/share/tomcat7
TOMCAT7_CONF_HOME=/etc/tomcat7

echo "Patching Tomcat 7 startup scripts"
if [ -f /opt/elasticbeanstalk/containerfiles/tomcat7-elasticbeanstalk ]; then
    echo "Installing tomcat7-elasticbeanstalk script"
    /bin/mv /opt/elasticbeanstalk/containerfiles/tomcat7-elasticbeanstalk /usr/sbin
    /bin/chown root:root /usr/sbin/tomcat7-elasticbeanstalk
    /bin/chmod 755 /usr/sbin/tomcat7-elasticbeanstalk
    echo "Fixing Tomcat 7 init.d script"
   /bin/sed -i -e 's/\/usr\/sbin\/tomcat7/\/usr\/sbin\/tomcat7-elasticbeanstalk/g' /etc/init.d/tomcat7
fi

# Apache config

echo "Creating ElasticBeanstalk Apache confs"

/bin/cat > /etc/httpd/conf.d/elasticbeanstalk.conf <<EOELASTICBEANSTALKSITE
<VirtualHost *:80>
  <Proxy *>
    Order deny,allow
    Allow from all
  </Proxy>

  ProxyPass / http://localhost:8080/ retry=0
  ProxyPassReverse / http://localhost:8080/
  ProxyPreserveHost on

  LogFormat "%h (%{X-Forwarded-For}i) %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\""
  ErrorLog /var/log/httpd/elasticbeanstalk-error_log
  TransferLog /var/log/httpd/elasticbeanstalk-access_log
</VirtualHost>
EOELASTICBEANSTALKSITE

# Tomcat misc config

## X-Forwarded-For support

echo "Adding X-Forwarded-Proto valve"
/bin/sed -i -e '/<\/Host>/ i\
    <Valve className="org.apache.catalina.valves.RemoteIpValve" protocolHeader="X-Forwarded-Proto" internalProxies="10\\.\\d+\\.\\d+\\.\\d+|192\\.168\\.\\d+\\.\\d+|169\\.254\\.\\d+\\.\\d+|127\\.\\d+\\.\\d+\\.\\d+|172\\.(1[6-9]|2[0-9]|3[0-1])\\.\\d+\\.\\d+" \/>
' $TOMCAT7_CONF_HOME/server.xml

# Make sure commons pool is available to tomcat.
ln -sf /usr/share/java/apache-commons-pool.jar /usr/share/tomcat7/lib/
}

if [[ -n "$EB_FIRST_RUN" ]];
then
  echo "Running preinit"
  preinit
else
  echo "Running preinit-reboot"
fi
