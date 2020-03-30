#!/bin/bash
apt update
apt install -y ruby-full ruby-bundler build-essential
echo "================="
ruby -v
bundler -v
echo "================="
