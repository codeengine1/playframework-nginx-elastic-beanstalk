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
sudo apt-get -y install monit

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

wget -O /etc/nginx/conf.d/debian.conf https://raw.githubusercontent.com/davemaple/playframework-nginx-elastic-beanstalk/master/nginx/debian.conf

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
wget -O /etc/monit/conf.d/monit.debian.conf https://raw.githubusercontent.com/davemaple/playframework-nginx-elastic-beanstalk/master/elasticbeanstalk/containerfiles/monit.debian.conf
echo 'Restarting monit service ...'
sudo service monit restart

echo 'Getting CA Certs'
sudo apt-get install --reinstall ca-certificates-java
sudo update-ca-certificates
rm /etc/ssl/certs/java/cacerts
/var/lib/dpkg/info/ca-certificates-java.postinst configure
