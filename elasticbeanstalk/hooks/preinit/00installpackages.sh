#!/bin/bash

set -xe

JAVA_VERSION=$(cat /opt/elasticbeanstalk/java_version)

yum install -y \
    tomcat7 \
    log4j \
    httpd \
    monit

if [ $JAVA_VERSION = "6" ]; then
    yum install -y \
        java-1.6.0-openjdk-devel

    ARCHITECTURE=`uname -m`
    if [ $ARCHITECTURE  = "x86_64" ]; then
        /usr/sbin/alternatives --set java /usr/lib/jvm/jre-1.6.0-openjdk.x86_64/bin/java
    elif [ $ARCHITECTURE = "i686" ]; then
        /usr/sbin/alternatives --set java /usr/lib/jvm/jre-1.6.0-openjdk/bin/java
    else
        echo "ERROR: ARCHITECTURE $ARCHITECTURE is not supported."
        exit 1
    fi

elif [ $JAVA_VERSION = "7" ]; then
    echo "no extra packages needed for Java 7"

else
  echo "ERROR: JAVA version $JAVA_VERSION is not supported."
  exit 1
fi
