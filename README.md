sudo yum -y update
sudo yum -y install git
cd /home/ec2-user/
sudo git clone https://github.com/davemaple/playframework-nginx-elastic-beanstalk.git
sudo chmod +x /home/ec2-user/playframework-nginx-elastic-beanstalk/install_nginx_play.sh
sudo /home/ec2-user/playframework-nginx-elastic-beanstalk/install_nginx_play.sh
