#!/bin/bash
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys 0xd68fa50fea312927
bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > \
  /etc/apt/sources.list.d/mongodb-org-3.2.list'
apt update
apt install -y mongodb-org
systemctl start mongod
systemctl enable mongod
echo "==============="
systemctl status mongod
echo "==============="
