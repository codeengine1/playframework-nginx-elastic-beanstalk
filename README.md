<h3 style="margin-bottom: 0.5em;">Install Nginx + Playframework on AWS Elastic Beanstalk</h3>
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

<table>
	<tr>
		<td>Latest Public AMI:</td>
		<td><strong>ami-b0f78fd8</strong></td>
		<td>January 22, 2015</td>
	</tr>
</table>