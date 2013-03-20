#!/usr/bin/env bash 

SOURCE_DIR=$(pwd)

#
# Package Installation
# 

# node.js using PPA (for StatsD)
sudo apt-get -y install python-software-properties
sudo apt-add-repository -y ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get -y install nodejs npm
 
# Install git to get StatsD
sudo apt-get -y install git
 
# System level dependencies for Graphite
sudo apt-get -y install memcached python-dev python-pip sqlite3 libcairo2 \
 libcairo2-dev python-cairo pkg-config

# System level dependencies for Erlang
sudo apt-get -y install build-essential libncurses5-dev openssl libssl-dev

# Dependencies for Basho Bench
sudo apt-get -y install r-recommended

# Dependencies for app
sudo apt-get -y install rubygems bc
sudo gem install statsd-ruby json daemons --no-ri --no-rdoc

# Install Apache
sudo apt-get -y install apache2 libapache2-mod-wsgi

# Get latest pip
sudo pip install --upgrade pip 

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
sudo cp /opt/graphite/conf/carbon.conf.example /opt/graphite/conf/carbon.conf
 
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
 
sudo cp /tmp/storage-schemas.conf /opt/graphite/conf/storage-schemas.conf

# Make sure log dir exists for webapp
sudo mkdir -p /opt/graphite/storage/log/webapp
 
# Copy over the local settings file
cat >> /tmp/local_settings.py << EOF
LOG_CACHE_PERFORMANCE = True
LOG_METRIC_ACCESS = True
LOG_RENDERING_PERFORMANCE = True
MEMCACHE_DURATION = 1
EOF

sudo cp /tmp/local_settings.py /opt/graphite/webapp/graphite/local_settings.py

# Initialize the database non-interactively.  Default superuser credentials are admin:admin
sudo cp $SOURCE_DIR/initial_data.json /opt/graphite/webapp/graphite/
sudo python /opt/graphite/webapp/graphite/manage.py syncdb --noinput

# Allow graphite web app to write to database and logs
sudo chown -R www-data /opt/graphite/storage

sudo cp /opt/graphite/conf/graphite.wsgi.example /opt/graphite/conf/graphite.wsgi

#
# Configure Apache
#
cat >> /tmp/graphite.conf << EOF
WSGISocketPrefix /var/run/apache2
<VirtualHost *:80>
        ServerName graphite
        DocumentRoot "/opt/graphite/webapp"

        WSGIDaemonProcess graphite processes=5 threads=5 display-name='%{GROUP}' inactivity-timeout=120
        WSGIProcessGroup graphite
        WSGIApplicationGroup %{GLOBAL}
        WSGIImportScript /opt/graphite/conf/graphite.wsgi process-group=graphite application-group=%{GLOBAL}

        WSGIScriptAlias / /opt/graphite/conf/graphite.wsgi

        Alias /content/ /opt/graphite/webapp/content/
        <Location "/content/">
                SetHandler None
        </Location>

        Alias /demo /opt/demo/
        <Location "/demo/">
                SetHandler None
                DirectoryIndex index.html
        </Location>

        # The graphite.wsgi file has to be accessible by apache. It won't
        # be visible to clients because of the DocumentRoot though.
        <Directory /opt/graphite/conf/>
                Order deny,allow
                Allow from all
        </Directory>

        ScriptAlias /cgi-bin/ /opt/app/
        <Directory "/usr/lib/cgi-bin">
                AllowOverride None
                Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
                Order allow,deny
                Allow from all
        </Directory>
</VirtualHost>
EOF

sudo cp /tmp/graphite.conf /etc/apache2/sites-available/

# Enable the graphite vhost
sudo ln -s /etc/apache2/sites-available/graphite.conf /etc/apache2/sites-enabled/graphite.conf
sudo rm -f /etc/apache2/sites-enabled/000-default

#
# Install StatsD
#
sudo git clone git://github.com/etsy/statsd.git /opt/statsd

cat >> /tmp/localConfig.js << EOF
{
  graphitePort: 2003
, graphiteHost: "127.0.0.1"
, port: 8125
, flushInterval: 1000
}
EOF
 
sudo cp /tmp/localConfig.js /opt/statsd/localConfig.js

#
# Install Erlang
#
wget http://erlang.org/download/otp_src_R15B01.tar.gz
tar zxvf otp_src_R15B01.tar.gz
cd otp_src_R15B01
./configure && make && sudo make install
cd ../ && rm -rf otp_src_R15B01 otp_src_R15B01.tar.gz

#
# Install Basho Bench
#
sudo git clone git://github.com/basho/basho_bench.git /opt/basho_bench
cd /opt/basho_bench

# Apply demo patch and compile
cp $SOURCE_DIR/graphite_demo.patch /opt/basho_bench/
git am --signoff < graphite_demo.patch
sudo make all
sudo chmod 755 /opt/basho_bench/basho_bench

# Set permissions so web app can interact with graphite and basho_bench
sudo mkdir /opt/basho_bench/config /opt/basho_bench/results /opt/basho_bench/state
sudo chown www-data /opt/basho_bench/config /opt/basho_bench/results /opt/basho_bench/state

# Install config template
cat >> /tmp/riakc_pb.template << EOF
{mode, max}.
{duration, 10}.
{concurrent, 5}.
{driver, basho_bench_driver_riakc_pb}.
{key_generator, {int_to_str, {partitioned_sequential_int, %START_OP%, %OPERATIONS%}}}.
{riakc_pb_bucket, <<"bench">>}.
{value_generator, {fixed_bin, 1}}.
{riakc_pb_ips, [{%IP%}]}.
{riakc_pb_replies, 2}.
{operations, [{%OPERATION%, 1}]}.

EOF

sudo cp /tmp/riakc_pb.template /opt/basho_bench/config/riakc_pb.template

#
# Install Demo app
#
sudo cp -R $SOURCE_DIR/app /opt/
sudo cp -R $SOURCE_DIR/demo /opt/

#
# rc.local configuration
#
cat >> /tmp/rc.local << EOF
# Purges old graphite data
rm -rf /opt/graphite/storage/whisper/*

# Starts graphite backend
python /opt/graphite/bin/carbon-cache.py start

# Starts StatsD
nohup node /opt/statsd/stats.js /opt/statsd/localConfig.js &

# Start Riak Poller
/opt/app/riak_poller_control.rb start

# Start Basho Bench Poller
/opt/app/bench_poller_control.rb start

exit 0
EOF

sudo cp /tmp/rc.local /etc/rc.local

#
# Start the services
#
sudo python /opt/graphite/bin/carbon-cache.py start
sudo nohup node /opt/statsd/stats.js /opt/statsd/localConfig.js &
sudo apache2ctl restart

touch /root/basho-bench-gui-installed
