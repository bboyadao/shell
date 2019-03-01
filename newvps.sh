#!/bin/bash

user="${whoami}"
echo $user
echo "Tiến hành setup trên vps mới"
echo "Cài đặt python3, nginx, uwsgi, postgresql..."
sudo su -c "ln -sf /bin/bash /bin/sh"
sudo su -c "apt-get update"
sudo su -c "apt-get -y install nginx python3 python3-pip python3-dev ufw  build-essential python3.6-dev postgresql postgresql-contrib supervisor libpcre3 libpcre3-dev"

sudo su -c "apt-get install -y software-properties-common"

sudo su -c "add-apt-repository -y universe"
sudo su -c "add-apt-repository -y ppa:certbot/certbot"
sudo su -c "apt-get update"
sudo su -c "apt-get -y install python-certbot-nginx"
sudo su -c "pip3 install wheel setuptools --no-cache-dir"
sudo su -c "pip3 install uwsgi  -I --no-cache-dir"
sudo su -c "pip3 install virtualenv virtualenvwrapper --no-cache-dir"
sudo su -c 'mkdir -p "/etc/uwsgi/sites"'
sudo su -c 'mkdir -p "/var/log/uwsgi"'

echo "export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3" >> ~/.bashrc
echo "export WORKON_HOME=~/virtualenvs" >> ~/.bashrc
echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.bashrc
source ~/.bashrc
echo "copy file config";

sudo su -c ':> /etc/systemd/system/uwsgi.service';
content=$(< "/home/$USER/uwsgi.service");
# echo "${content/my_user/$USER}" | sudo tee '/etc/systemd/system/uwsgi.service'
echo """
[Unit]
Description=uWSGI Emperor service
[Service]
ExecStartPre=/bin/bash -c 'mkdir -p /run/uwsgi; chown $USER:www-data /run/uwsgi'
ExecStart=/usr/local/bin/uwsgi --emperor /etc/uwsgi/sites
Restart=always
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all
[Install]
WantedBy=multi-user.target
""" | sudo tee '/etc/systemd/system/uwsgi.service'

sudo su -c ':> /etc/supervisor/conf.d/uwsgi.conf'

# sudo su -c "cat uwsgi.conf >> /etc/supervisor/conf.d/uwsgi.conf"
echo """

[program:uwsgi]
command=/usr/local/bin/uwsgi --emperor /etc/uwsgi/apps-enabled
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
stdout_logfile=/var/log/uwsgi.log

""" | sudo tee '/etc/supervisor/conf.d/uwsgi.conf'


sudo su -c 'supervisorctl reread'
sudo su -c 'sudo supervisorctl update'
