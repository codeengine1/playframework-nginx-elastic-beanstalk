#!/bin/sh

# JDK v8
# Play 2.3.X
# run as root

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

echo 'Starting nginx'
sudo service nginx start

echo 'Nginx is installed'

echo 'Creating app directory'
mkdir /var/app

echo 'Downloading Playframework ...'
cd /opt/
wget -P /opt/ http://downloads.typesafe.com/typesafe-activator/1.2.10/typesafe-activator-1.2.10-minimal.zip
unzip /opt/typesafe-activator-1.2.10-minimal.zip
rm -f /opt/typesafe-activator-1.2.10-minimal.zip
chmod a+x /opt/activator-1.2.10-minimal/activator

echo 'Adding Play to the PATH ...'
export PATH=$PATH:/opt/activator-1.2.10-minimal/
echo '#! /bin/sh
export PATH=$PATH:/opt/activator-1.2.10-minimal/
' > /etc/profile.d/play.sh
chmod +x /etc/profile.d/play.sh

echo 'Test script for Elastic Beanstalk ...'
echo '#! /bin/sh
/opt/elasticbeanstalk/hooks/appdeploy/pre/01stage.sh
/opt/elasticbeanstalk/hooks/appdeploy/enact/01stop.sh
/opt/elasticbeanstalk/hooks/appdeploy/post/01start.sh
' > /etc/init.d/ebdeploy.sh
chmod +x /etc/init.d/ebdeploy.sh

echo 'Adding play startup script'

echo '#! /bin/sh

### BEGIN INIT INFO
# Provides:          play
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description:
# Description:
### END INIT INFO

. /etc/rc.d/init.d/functions

APP="playapp"
APP_PATH="/var/app/$APP"

start() {

  cp /opt/elasticbeanstalk/deploy/appsource/source_bundle /var/app/playapp.zip
  rm -fR $APP_PATH/*
  unzip "$APP_PATH.zip" -d $APP_PATH
  rm "$APP_PATH.zip"
  unlink /var/app/current
  ln -s $APP_PATH/*/ /var/app/current

  CONFIG_FILE="application.conf"

  if [ -f $APP_PATH/*/conf/rc.application.conf ]; then
    CONFIG_FILE="rc.application.conf"
  fi

#  if [ -f $APP_PATH/*/conf/live.application.conf ]; then
#    CONFIG_FILE="live.application.conf"
#  fi

	BIN=`find $APP_PATH/*/bin -not -name "*.bat" -not -type d`
  $BIN -J-Xms64M -J-Xmx256m -Dpidfile.path=/var/run/play.pid -Dconfig.file=/var/app/current/conf/$CONFIG_FILE -Dnetworkaddress.cache.ttl=60>/dev/null 2>&1 &
#  $BIN -J-Xms256M -J-Xmx2048m -Dpidfile.path=/var/run/play.pid -Dconfig.file=/var/app/current/conf/$CONFIG_FILE -Dnetworkaddress.cache.ttl=60>/dev/null 2>&1 &

  /usr/bin/monit monitor play
  return 0
}

stop() {
  PLAY_PROCESS=""

  if [ -f /var/run/play.pid ]; then
    PLAY_PROCESS=$(cat /var/run/play.pid)
  else 
    PLAY_PROCESS=$(ps aux | grep '[p]lay' | awk '{print $2}')
  fi

  if [ "$PLAY_PROCESS" != "" ]; then
    kill $PLAY_PROCESS
  fi

  return 0
}


status() {
  if [ -f /var/run/play.pid ]; then
    exit 0;
  else 
    exit 1;
  fi
}

case "$1" in
  start)
    start
    exit 0
    ;;
  stop)
    stop
    ;;
  restart)
    echo  "Restarting $APP."
    stop
    sleep 2
    start
    echo "$APP restarted."
    ;;
  status)
    echo  "Checking status"
    status
    ;;
  *)
    N=/etc/init.d/play.$APP
    echo "Usage: $N {start|stop|restart}" >&2
    exit 1
    ;;
esac

exit 0' > /etc/init.d/play
chmod +x /etc/init.d/play

echo 'Making sure that play starts on startup'
/sbin/chkconfig play on

echo 'Removing tomcat...'
yum -y remove tomcat7

echo 'Downloading sample test app for play'
cd /home/ec2-user/
wget --output-document playtest.zip https://github.com/davemaple/playframework-example-application-mode/blob/master/playtest.zip?raw=true
cp playtest.zip /opt/elasticbeanstalk/deploy/appsource/source_bundle

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



