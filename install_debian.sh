#!/bin/sh

# run as root
# wheezy: last tested on 2015/02/18

# update any available packages
apt-get update
apt-get -y upgrade

# install memcached
echo 'Installing memcached ...'
sudo apt-get install memcached
update-rc.d memcached defaults

# add unstable repos
echo '

#### unstable #########\ndeb http://ftp.us.debian.org/debian unstable main contrib non-free

' >> /etc/apt/sources.list
apt-get update

# install monit
sudo apt-get install monit

# install java
apt-get -y --no-install-recommends --force-yes -t unstable install openjdk-8-jdk

# update dns cache TTL to 60 seconds
echo '
networkaddress.cache.ttl = 0
networkaddress.cache.negative.ttl = 0
' >> /usr/lib/jvm/java-1.8*openjdk*/jre/lib/security/java.security

# add jq to parse JSON
wget --output-document /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq
chmod +x /usr/bin/jq

echo 'Creating nginx cache directory'
mkdir /data
mkdir /data/nginx
mkdir /data/nginx/cache

echo 'Installing nginx...'
apt-get -y --no-install-recommends --force-yes install nginx

echo 'Fixing nginx configuration'
sed -i 's/worker_processes 4;/worker_processes 1;/g' /etc/nginx/nginx.conf
sed -i 's/worker_connections 768;/worker_connections 1024;/g' /etc/nginx/nginx.conf
sed -i '/sites-enabled/d' /etc/nginx/nginx.conf

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

echo $'
proxy_cache_path /data/nginx/cache keys_zone=assets:10m max_size=2000m;

log_format playframework \'$remote_addr "$cookie_visitorId" $time_iso8601 "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $body_bytes_sent $msec $request_time\';

real_ip_header X-Forwarded-For;
set_real_ip_from 10.0.0.0/8;
real_ip_recursive on;

server {

    listen 80;
    server_name _;
    access_log /var/log/nginx/play.access.log playframework;
    error_log /var/log/nginx/play.error.log;
    
    ## Start: Size Limits & Buffer Overflows ##
	client_body_buffer_size  1K;
	client_header_buffer_size 1k;
	client_max_body_size 64k;
	large_client_header_buffers 2 8k;
	## END: Size Limits & Buffer Overflows ##
  
	## Start: Timeouts ##
	client_body_timeout   10;
	client_header_timeout 10;
	keepalive_timeout     5 5;
	send_timeout          10;
	## End: Timeouts ##

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
}

server {
    listen 443;
    server_name _;
    access_log /var/log/nginx/ssl.play.access.log playframework;
    error_log /var/log/nginx/ssl.play.error.log;
    ssl on;
    ssl_certificate     /opt/elasticbeanstalk/deploy/ssl/ssl.crt;
    ssl_certificate_key /opt/elasticbeanstalk/deploy/ssl/ssl.key;

    #set the default location
    location /assets/ {
        proxy_set_header        Host $host;
        proxy_set_header        X-Real-IP $remote_addr;
        proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto $scheme;
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
        proxy_set_header        Host $host;
        proxy_set_header        X-Real-IP $remote_addr;
        proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade"; 
    }

    location / {
        proxy_set_header        Host $host;
        proxy_set_header        X-Real-IP $remote_addr;
        proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto $scheme;
        add_header Cache-Control "no-store, must-revalidate";
        add_header Pragma no-cache;
        expires epoch;
        proxy_pass         http://127.0.0.1:9000/;
    }
}
' > /etc/nginx/conf.d/playframework.conf

echo 'Creating source deployment directory ...'
mkdir /opt/elasticbeanstalk
mkdir /opt/elasticbeanstalk/deploy
mkdir /opt/elasticbeanstalk/deploy/appsource
mkdir /opt/elasticbeanstalk/deploy/configuration
mkdir /opt/elasticbeanstalk/deploy/ssl

wget -O /opt/elasticbeanstalk/deploy/ssl/ssl.key https://raw.githubusercontent.com/davemaple/playframework-nginx-elastic-beanstalk/master/ssl/ssl.key
wget -O /opt/elasticbeanstalk/deploy/ssl/ssl.crt https://raw.githubusercontent.com/davemaple/playframework-nginx-elastic-beanstalk/master/ssl/ssl.crt

echo 'Making sure that nginx starts on startup'
update-rc.d nginx defaults

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
unset DISPLAY

echo 'Adding play startup script'
wget -O /etc/init.d/play https://raw.githubusercontent.com/davemaple/playframework-nginx-elastic-beanstalk/master/play
chmod +x /etc/init.d/play
sed -i '/rc.d/d' /etc/init.d/play

echo 'Making sure that play starts on startup'
update-rc.d play defaults

echo 'Downloading sample test app for play'
wget -O /opt/elasticbeanstalk/deploy/appsource/source_bundle https://github.com/davemaple/playframework-example-application-mode/blob/master/playtest.zip?raw=true

echo 'Loading base configuration'
wget -O /opt/elasticbeanstalk/deploy/configuration/containerconfiguration https://raw.githubusercontent.com/davemaple/playframework-nginx-elastic-beanstalk/master/containerconfig/debian-basic.json

echo 'Starting up play'
sudo service play start

echo 'Reconfiguring monit ... '
wget -O /etc/monit/conf.d/monit.debian.conf https://raw.githubusercontent.com/davemaple/playframework-nginx-elastic-beanstalk/master/elasticbeanstalk/containerfiles/monit.conf
echo 'Restarting monit service ...'
sudo service monit restart

echo 'Getting CA Certs'
sudo apt-get install --reinstall ca-certificates-java
sudo update-ca-certificates
rm /etc/ssl/certs/java/cacerts
/var/lib/dpkg/info/ca-certificates-java.postinst configure
