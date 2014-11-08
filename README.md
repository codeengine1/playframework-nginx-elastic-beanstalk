<h3 style="margin-bottom: 0.5em;">Install Nginx + Playframework on AWS Elastic Beanstalk</h3>
<p>
First, create a tomcat application on Elastic Beanstalk. Then SSH onto the EC2 Instance created and run the following commands:
</p>


<pre>
sudo yum -y update
sudo yum -y install git
cd /home/ec2-user/
sudo git clone https://github.com/davemaple/playframework-nginx-elastic-beanstalk.git
sudo chmod +x /home/ec2-user/playframework-nginx-elastic-beanstalk/install_nginx_play.sh
sudo /home/ec2-user/playframework-nginx-elastic-beanstalk/install_nginx_play.sh
</pre>
