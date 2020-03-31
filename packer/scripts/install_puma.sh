#! /bin/bash
git clone -b monolith https://github.com/express42/reddit.git
cd reddit && bundle install
mv /tmp/puma.service /etc/systemd/system/puma.service
systemctl enable puma
