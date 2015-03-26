<h3 style="margin-bottom: 0.5em;">Nginx + Playframework on AWS Elastic Beanstalk</h3>

<table border="0">
	<tr>
		<td><img src="http://cdn2.hubspot.net/hub/362403/file-1158785862-png/elastic_beanstalk.png" width="75" /></td>
		<td style="padding-left: 45px;"><img src="https://www.playframework.com/assets/images/logos/play_full_color.svg" width="100" /></td>
		<td style="padding-left: 35px;"><img src="http://nginx.org/nginx.png" width="100" /></td>
	</tr>
	<tr>
		<td>Latest Public AMI:</td>
		<td><strong>ami-da517ab2</strong></td>
		<td>March 25, 2015</td>
	</tr>
</table>

<h3>Instructions for building a new custom AMI</h3>

<p>
First, create a tomcat application on Elastic Beanstalk. Then SSH onto the EC2 Instance created and run the following commands:
</p>


<pre>
sudo su
yum -y update
yum -y install git
cd /home/ec2-user/
git clone https://github.com/davemaple/playframework-nginx-elastic-beanstalk.git
chmod +x /home/ec2-user/playframework-nginx-elastic-beanstalk/install_nginx_play.sh
/home/ec2-user/playframework-nginx-elastic-beanstalk/install_nginx_play.sh
echo 'done!'

</pre>

