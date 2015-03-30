#!/bin/sh

# JDK v8
# Play 2.3.X
# run as root

# update dns cache TTL to 60 seconds
echo '
networkaddress.cache.ttl = 0
networkaddress.cache.negative.ttl = 0
' >> /usr/lib/jvm/jre/lib/security/java.security

yum -y update
yum -y install git
cd /home/ec2-user/

# add jq to parse JSON
wget --output-document /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq
chmod +x /usr/bin/jq

echo 'Creating nginx cache directory'
mkdir /data
mkdir /data/nginx
mkdir /data/nginx/cache

echo 'Installing local memcached...'
yum -y install memcached
service memcached start
/sbin/chkconfig memcached on

echo 'Installing nginx...'
yum -y install nginx

echo 'Fixing nginx configuration'
sed -i 's/worker_processes  1;/worker_processes  2;/g' /etc/nginx/nginx.conf
rm -f /etc/nginx/conf.d/virtual.conf

wget -O /etc/nginx/conf.d/beanstalk.conf https://raw.githubusercontent.com/davemaple/playframework-nginx-elastic-beanstalk/master/nginx/beanstalk.conf

echo 'Making sure that nginx starts on startup'
/sbin/chkconfig nginx on

echo 'Removing apache...'
yum -y remove httpd
rm -f /etc/monit.d/monit-apache.conf

echo 'Nginx is installed'

echo 'Creating app directory'
mkdir /var/app

echo 'Downloading Playframework ...'
cd /opt/
wget -P /opt/ http://downloads.typesafe.com/typesafe-activator/1.2.12/typesafe-activator-1.2.12-minimal.zip
unzip /opt/typesafe-activator-1.2.12-minimal.zip
rm -f /opt/typesafe-activator-1.2.12-minimal.zip
chmod a+x /opt/activator-1.2.12-minimal/activator

echo 'Adding Play to the PATH ...'
echo '#! /bin/sh
export PATH=$PATH:/opt/activator-1.2.12-minimal/
' > /etc/profile.d/play.sh
chmod +x /etc/profile.d/play.sh
source /etc/profile.d/play.sh

echo 'Test script for Elastic Beanstalk ...'
echo '#! /bin/sh
/opt/elasticbeanstalk/hooks/appdeploy/pre/01stage.sh
/opt/elasticbeanstalk/hooks/appdeploy/enact/01stop.sh
/opt/elasticbeanstalk/hooks/appdeploy/post/01start.sh
' > /etc/init.d/ebdeploy.sh
chmod +x /etc/init.d/ebdeploy.sh

echo 'Adding play startup script'

cp /home/ec2-user/playframework-nginx-elastic-beanstalk/play /etc/init.d/play
chmod +x /etc/init.d/play

echo 'Making sure that play starts on startup'
/sbin/chkconfig play on

echo 'Removing tomcat...'
yum -y remove tomcat8
rm -f /etc/monit.d/monit-tomcat8.conf

echo 'Downloading sample test app for play'
cd /home/ec2-user/
wget --output-document /var/app/playapp.zip https://github.com/davemaple/playframework-example-application-mode/blob/master/playtest.zip?raw=true
cp /var/app/playapp.zip /opt/elasticbeanstalk/deploy/appsource/source_bundle

echo 'Configuring Elastic Beanstalk for Playframework deployment ... '
cd /home/ec2-user
rm -fR /opt/elasticbeanstalk/hooks
cp -a /home/ec2-user/playframework-nginx-elastic-beanstalk/elasticbeanstalk/hooks /opt/elasticbeanstalk/
rm -fR /opt/elasticbeanstalk/tasks
cp -a /home/ec2-user/playframework-nginx-elastic-beanstalk/elasticbeanstalk/tasks /opt/elasticbeanstalk/
rm -fR /opt/elasticbeanstalk/containerfiles
cp -a /home/ec2-user/playframework-nginx-elastic-beanstalk/elasticbeanstalk/containerfiles /opt/elasticbeanstalk/

echo 'Starting nginx'
sudo service nginx start

echo 'Starting up play'
sudo service play start

echo 'Configuring logs ...'
cp /home/ec2-user/playframework-nginx-elastic-beanstalk/ebname.py /usr/bin/ebname.py
chmod +x /usr/bin/ebname.py
rm -f /etc/logrotate.d/logrotate.elasticbeanstalk.tomcat8.conf
rm -f /etc/logrotate.d/logrotate.elasticbeanstalk.httpd.conf
rm -f /etc/logrotate.d/httpd
sudo yum install -y awslogs
cp -f /home/ec2-user/playframework-nginx-elastic-beanstalk/awslogs.conf /etc/awslogs/awslogs.conf
ELASTIC_BEANSTALK_ENVIRONMENT="$( ebname.py )"
sed -i "s/{environment_name}/$ELASTIC_BEANSTALK_ENVIRONMENT/g" /etc/awslogs/awslogs.conf
sudo chkconfig awslogs on
service awslogs start

echo 'Reconfiguring monit ... '
cp -f /opt/elasticbeanstalk/containerfiles/monit.conf /etc/monit.d/monit.conf
echo 'Restarting monit service ...'
sudo service monit restart

echo 'Creating awslogs template ... '
cp -f /home/ec2-user/playframework-nginx-elastic-beanstalk/awslogs.conf /opt/elasticbeanstalk/containerfiles/awslogs.conf

echo 'Cleaning up ... '
yum -y remove git
cd /root
rm -fR /home/ec2-user/*



