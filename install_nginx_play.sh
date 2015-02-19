#!/bin/sh

# JDK v8
# Play 2.3.X
# run as root

# update dns cache TTL to 60 seconds
echo '
networkaddress.cache.ttl = 0\nnetworkaddress.cache.negative.ttl = 0
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

echo 'Installing nginx...'
yum -y install nginx

echo 'Fixing nginx configuration'
sed -i 's/worker_processes  1;/worker_processes  2;/g' /etc/nginx/nginx.conf
rm -f /etc/nginx/conf.d/virtual.conf

echo 'Creating configuration files'
echo 'proxy_redirect      off;
proxy_set_header          Host            $host;
proxy_set_header          X-Real-IP       $remote_addr;
proxy_set_header          X-Forwarded-For $proxy_add_x_forwarded_for;
client_max_body_size      10m;
client_body_buffer_size   128k;
client_header_buffer_size 64k;
proxy_connect_timeout     90;
proxy_send_timeout        90;
proxy_read_timeout        90;
proxy_buffer_size         16k;
proxy_buffers             32              16k;
proxy_busy_buffers_size   64k;' > /etc/nginx/conf.d/proxy.conf

echo '
proxy_cache_path /data/nginx/cache keys_zone=assets:10m max_size=2000m;

log_format playframework ''$remote_addr\t"$cookie_visitorId"\t$time_iso8601\t"$request"\t$status\t$body_bytes_sent\t"$http_referer"\t"$http_user_agent"\t$body_bytes_sent\t$msec\t$request_time'';

real_ip_header X-Forwarded-For;
set_real_ip_from 10.0.0.0/8;
real_ip_recursive on;

server {
 listen 80;
 server_name _;
 access_log /var/log/httpd/elasticbeanstalk-access_log playframework;
 error_log /var/log/httpd/elasticbeanstalk-error_log;

 #set the default location
 location /assets/ {
  proxy_cache assets;
  proxy_cache_valid 200 180m;
  expires max;
  add_header Cache-Control public;
  proxy_pass         http://127.0.0.1:9000/assets/;
 }

 #websocket support
 location /websocket/ {
  proxy_pass http://127.0.0.1:9000/websocket/;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade"; 
 }

 location / {
  add_header Cache-Control "no-store, must-revalidate";
  add_header Pragma no-cache;
  expires epoch;
  proxy_pass         http://127.0.0.1:9000/;
 }

 # make sure the hostmanager works
 location /_hostmanager/ {
  proxy_pass         http://127.0.0.1:8999/;
 }
}' > /etc/nginx/conf.d/beanstalk.conf

echo 'Making sure that nginx starts on startup'
/sbin/chkconfig nginx on

echo 'Removing apache...'
yum -y remove httpd
rm -f /etc/monit.d/monit-apache.conf

echo 'Restarting nginx'
sudo service nginx restart

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

echo 'Starting up play'
sudo service play start

echo 'Configuring Elastic Beanstalk for Playframework deployment ... '
cd /home/ec2-user
rm -fR /opt/elasticbeanstalk/hooks
cp -a /home/ec2-user/playframework-nginx-elastic-beanstalk/elasticbeanstalk/hooks /opt/elasticbeanstalk/
rm -fR /opt/elasticbeanstalk/tasks
cp -a /home/ec2-user/playframework-nginx-elastic-beanstalk/elasticbeanstalk/tasks /opt/elasticbeanstalk/
rm -fR /opt/elasticbeanstalk/containerfiles
cp -a /home/ec2-user/playframework-nginx-elastic-beanstalk/elasticbeanstalk/containerfiles /opt/elasticbeanstalk/

echo 'Reconfiguring monit ... '
cp -f /opt/elasticbeanstalk/containerfiles/monit.conf /etc/monit.d/monit.conf
echo 'Restarting monit service ...'
sudo service monit restart

echo 'Cleaning up ... '
yum -y remove git
cd /root
rm -fR /home/ec2-user/*



