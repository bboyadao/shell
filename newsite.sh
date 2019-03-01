#!/bin/bash
user="${USER}"
echo $user
echo "Nhập domain"
read domain
echo "Nhập Link Git"
read linkgit

IFS='.' read -r -a domainname <<< "$domain"
sleep 0
echo "----------SETUP DATABASE---------- "
sudo -u postgres psql --command "CREATE DATABASE $domainname;"
sudo -u postgres psql --command "CREATE USER $domainname WITH PASSWORD '$domainname-$domainname';"
sudo -u postgres psql --command "ALTER ROLE $domainname SET client_encoding TO 'utf8';"
sudo -u postgres psql --command "ALTER ROLE $domainname SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql --command "ALTER ROLE $domainname SET timezone TO 'UTC';"
sudo -u postgres psql --command "GRANT ALL PRIVILEGES ON DATABASE $domainname TO $domainname;"



echo "----------SETUP VIRTUALENV---------- "
source /usr/local/bin/virtualenvwrapper.sh
# wrraper
mkvirtualenv $domainname
workon $domainname
sudo su -c "mkdir -p projects/$domainname"

sudo git clone $linkgit /home/$user/projects/$domainname
pip -V
pip  install -r "/home/$user/projects/$domainname/requirements.txt"

django_settings=$(< "/home/$user/projects/$domainname/newstubacninh/settings.py")
echo "${django_settings/custom_database/$domainname}" | sudo tee "/home/$user/projects/$domainname/newstubacninh/settings.py"
sudo su -c "chown -R $user:$user  /home/$user/projects/$domainname/staticfiles"

python /home/$user/projects/$domainname/manage.py collectstatic --noinput --clear

python /home/$user/projects/$domainname/manage.py migrate
# chown -R /home/$user/projects/$domainname/staticfile

deactivate
echo "---------- SETUP uWSGI ---------------"



if [ ! -f "/etc/uwsgi/sites/$domainname.ini" ]; then
    sudo su -c "touch /etc/uwsgi/sites/$domainname.ini"
fi

sudo su -c ":> /etc/uwsgi/sites/$domainname.ini"
sudo su -c "chown -R $user:$user /var/log/uwsgi/"




echo "
[uwsgi]
domainname = $domainname
project = newstubacninh
uid = $user
base = /home/%(uid)
home = %(base)/virtualenvs/%(domainname)
chdir = %(base)/projects/%(domainname)
module = %(project).wsgi:application
daemonize=/var/log/uwsgi/daemon-%n.log
logto = /var/log/uwsgi/%n.log
master = true
processes = 5

socket = /run/uwsgi/%(domainname).sock
chown-socket = %(uid):www-data
chmod-socket = 660
vacuum = true
" | sudo tee "/etc/uwsgi/sites/$domainname.ini"
sudo touch /var/log/uwsgi/$domainname.log
sudo su -c "chown -R $user:$user /var/log/uwsgi/$domainname.log"

echo "---------- SETUP SCRAPYD ---------------"

echo "
[program:scrapyd_$domainname]
command = source home/$user/virtualenvs/$domainname/bin/activate
directory = /home/$user/projects/$domainname/crawler_news
command = /home/$user/virtualenvs/$domainname/bin/scrapyd
autostart = true
autorestart = true
redirect_stderr = true
stdout_logfile = /var/log/supervisor/$domainname.log
stderr_logfile = /var/log/supervisor/$domainname_errors.log
" | sudo tee "/etc/supervisor/conf.d/$domainname.conf"

echo "---------- SETUP NGINX ---------------"
sudo su -c ":> /etc/nginx/sites-available/$domainname"


# echo "${content/domainname/$domainname/domain/$domain}" | sudo tee "/etc/nginx/sites-available/$domainname"


echo "
server {
  listen 80;
  server_name $domain www.$domain "`echo '$server_addr'`";

  location = /favicon.ico { access_log off; log_not_found off; }
  location /static {

      alias /home/$user/projects/$domainname/staticfiles;
  }

  location / {
      include         uwsgi_params;
      uwsgi_pass      unix:/run/uwsgi/$domainname.sock;
  }
  }

" | sudo tee "/etc/nginx/sites-available/$domainname"

sudo su -c "ln -s /etc/nginx/sites-available/$domainname /etc/nginx/sites-enabled"

sudo nginx -t
sudo ufw status
# sudo ufw enable

sudo ufw allow 'Nginx Full'
sudo ufw delete allow 'Nginx HTTP'
sudo ufw status
#
sudo certbot --nginx -d $domain -d www.$domain --force-renewal
sudo certbot renew --dry-run
sudo systemctl daemon-reload
sudo systemctl restart uwsgi
sudo systemctl start uwsgi
sudo systemctl enable uwsgi && sudo service uwsgi start



sudo systemctl restart nginx
sudo systemctl reload nginx
sudo systemctl start nginx
sudo supervisorctl reload
sudo supervisorctl reread
sudo supervisorctl status
