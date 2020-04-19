#!/bin/bash
set -e

APP_DIR=${1:-$HOME}

git clone -b monolith https://github.com/express42/reddit.git $APP_DIR/reddit
cd $APP_DIR/reddit
bundle install

mv /tmp/puma.service /etc/systemd/system/puma.service
systemctl start puma
systemctl enable puma
