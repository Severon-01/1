#!/bin/bash
apt-get install -y zoneminder zoneminder-api zoneminder-nginx nginx spawn-fcgi fcgiwrap
apt-get install MySQL-server
service mysqld enable
service mysqld start
mysql
CREATE USER 'zmuser'@localhost IDENTIFIED BY 'zmpass';
create database zm;
use zm;
source /usr/share/zoneminder/db/zm_create.sql;
grant select,insert,update,delete on zm.* to 'zmuser'@localhost;
exit;
systemctl enable --now zoneminder
sed -i "s/USERID=_spawn_fcgi/USERID=apache/g" /etc/sysconfig/spawn-fcgi
sed -i "18s/^/#/" /etc/nginx/nginx.conf
cd /etc/nginx/sites-enabled.d/
cat << 'EOF' >> zoneminder.conf
server {
	listen  127.0.0.1:443;
	rewrite ^/(.*)$ http://$host/$1 permanent;
}

server {
        listen  80;
        types_hash_bucket_size 128;
        allow all;

        location / {
            root        /usr/share/zoneminder/www;
            rewrite ^/zm/(.*) /$1 break;
            index       index.php;
        }


        location /cgi-bin/zm {
                root   /usr/lib/zoneminder/cgi-bin;
                autoindex on;
                index  index.cgi;
                        
        }
        
        location ~ nph-zms$ {
                root    /usr/lib/zoneminder/cgi-bin;
                rewrite ^/cgi-bin/zm/(.*) /$1 break;
 
                include /etc/nginx/fastcgi_params;
 
                fastcgi_pass   unix:/var/run/spawn-fcgi/spw-cgi.sock;
                fastcgi_param  SCRIPT_FILENAME  /usr/lib/zoneminder/cgi-bin/$fastcgi_script_name;
        }

        location ~ /\.ht {
            deny all;
        }

        location ~ \.php$ {
            root /usr/share/zoneminder/www;
            rewrite ^/zm/(.*) /$1 break;
            include        fastcgi_params;
            include sites-enabled.d/zm-fcgi.inc;
            fastcgi_param  SCRIPT_FILENAME  /usr/share/zoneminder/www/$fastcgi_script_name;
            fastcgi_param  DOCUMENT_ROOT /usr/share/zoneminder/www;
        }

        access_log  /var/log/nginx/access.log;
}
EOF
usermod -a -G video apache
systemctl enable --now  mysqld
systemctl enable --now nginx
systemctl enable --now zoneminder
systemctl enable --now spawn-fcgi
systemctl enable --now php8.3-fpm


