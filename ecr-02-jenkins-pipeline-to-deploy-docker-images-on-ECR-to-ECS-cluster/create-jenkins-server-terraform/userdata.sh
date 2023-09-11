#! /bin/bash
# update os
dnf update -y
# install git
dnf install git -y
# set server hostname as Jenkins-Server
hostnamectl set-hostname "Jenkins-Server"
# install java 11
dnf upgrade
dnf install java-11-amazon-corretto -y
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
# install jenkins
dnf install jenkins -y
systemctl enable jenkins
systemctl start jenkins
# install docker
dnf install docker -y
systemctl start docker
systemctl enable docker
#add ec2-user and jenkins users to docker group
usermod -a -G docker ec2-user
usermod -a -G docker jenkins
# configure docker as cloud agent for jenkins
cp /lib/systemd/system/docker.service /lib/systemd/system/docker.service.bak
sed -i 's/^ExecStart=.*/ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:2376 -H unix:\/\/\/var\/run\/docker.sock/g' /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker
systemctl restart jenkins
cd /home/ec2-user
wget https://github.com/awsdevopsteam/jenkins-first-project/raw/master/to-do-app-nodejs.tar
tar -xvf to-do-app-nodejs.tar
rm to-do-app-nodejs.tar
git clone https://${github_username}:${user-data-git-token}@github.com/${github_username}/${git-repo-name}.git
cd todo-app-node-project
cp -R /home/ec2-user/to-do-app-nodejs/* /home/ec2-user/todo-app-node-project/
git config --global user.email ${github_email}
git config --global user.name ${github_username}
git add .
git commit -m 'added todo app'
git push
chown -R  ec2-user:ec2-user /home/ec2-user/todo-app-node-project/