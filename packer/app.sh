#!/bin/bash

sleep 30

sudo yum update -y

sudo yum install -y gcc-c++ make
curl -sL https://rpm.nodesource.com/setup_14.x | sudo -E bash -
sudo yum install -y nodejs

sudo yum install unzip -y
cd ~/ && unzip social_something_full.zip
cd ~/social_something_full && npm i --only=prod

touch app.env

sudo mv /tmp/social_something.service /etc/systemd/system/social_something.service
sudo systemctl enable social_something.service
sudo systemctl start social_something.service

