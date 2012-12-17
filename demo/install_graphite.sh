#!/bin/bash
 
# node.js using PPA (for statsd)
sudo apt-get -y install python-software-properties
sudo apt-add-repository ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get -y install nodejs npm
 
# Install git to get statsd
sudo apt-get -y install git
 
# System level dependencies for Graphite
sudo apt-get -y install memcached python-dev python-pip sqlite3 libcairo2 \
 libcairo2-dev python-cairo pkg-config

# System level dependencies for Erlang
sudo apt-get -y install build-essential libncurses5-dev openssl libssl-dev

# Dependencies for Basho Bench
sudo apt-get -y install r-recommended

# Install Apache
sudo apt-get -y install apache2 libapache2-mod-wsgi
 
# Get latest pip
sudo pip install -y --upgrade pip 
 
# Install carbon and graphite deps 
cat >> /tmp/graphite_reqs.txt << EOF
django==1.3
python-memcached
django-tagging
twisted
whisper==0.9.9
carbon==0.9.9
graphite-web==0.9.9
EOF
 
sudo pip install -r /tmp/graphite_reqs.txt
 
#
# Configure carbon
#
cd /opt/graphite/conf/
sudo cp carbon.conf.example carbon.conf
 
# Create storage schema and copy it over
# Using the sample as provided in the statsd README
# https://github.com/etsy/statsd#graphite-schema
 
cat >> /tmp/storage-schemas.conf << EOF
# Schema definitions for Whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds.
#
#  [name]
#  pattern = regex
#  retentions = timePerPoint:timeToStore, timePerPoint:timeToStore, ...
[stats]
priority = 110
pattern = ^stats\..*
retentions = 1s:6h
EOF
 
sudo cp /tmp/storage-schemas.conf storage-schemas.conf
 
# Make sure log dir exists for webapp
sudo mkdir -p /opt/graphite/storage/log/webapp
 
# Copy over the local settings file and initialize database
cd /opt/graphite/webapp/graphite/

cat >> /tmp/local_settings.py << EOF
LOG_CACHE_PERFORMANCE = True
LOG_METRIC_ACCESS = True
LOG_RENDERING_PERFORMANCE = True
MEMCACHE_DURATION = 1
EOF

sudo cp /tmp/local_settings.py local_settings.py

sudo python manage.py syncdb  # Follow the prompts, creating a superuser is optional
 
# statsd
cd /opt && sudo git clone git://github.com/etsy/statsd.git
 
# StatsD configuration
cat >> /tmp/localConfig.js << EOF
{
  graphitePort: 2003
, graphiteHost: "127.0.0.1"
, port: 8125
, flushInterval: 1000
}
EOF
 
sudo cp /tmp/localConfig.js /opt/statsd/localConfig.js

# rc.local configuration
cat >> /tmp/rc.local << EOF
rm -rf /opt/graphite/storage/whisper/*
python /opt/graphite/bin/carbon-cache.py start
nohup node /opt/statsd/stats.js /opt/statsd/localConfig.js &
EOF

sudo cp /tmp/rc.local /etc/rc.local

# Erlang
cd /tmp
wget http://erlang.org/download/otp_src_R15B01.tar.gz
tar zxvf otp_src_R15B01.tar.gz
cd otp_src_R15B01
./configure && make && sudo make install
cd ../ && rm -rf otp_src_R15B01 otp_src_R15B01.tar.gz

# Basho Bench
cd /opt && sudo git clone git://github.com/basho/basho_bench.git
cd basho_bench
make all
