#!/bin/bash
apt-get update
apt-get install wget -y
apt-get install -y zoneminder zoneminder-api zoneminder-nginx nginx spawn-fcgi fcgiwrap
apt-get install MySQL-server
service mysqld enable
service mysqld start
sleep 10

mysql <<EOF
CREATE USER 'zmuser'@localhost IDENTIFIED BY 'zmpass';
create database zm;
use zm;
source /usr/share/zoneminder/db/zm_create.sql;
grant select,insert,update,delete on zm.* to 'zmuser'@localhost;
EOF
systemctl enable --now zoneminder
sed -i "s/USERID=_spawn_fcgi/USERID=apache/g" /etc/sysconfig/spawn-fcgi
sed -i "18s/^/#/" /etc/nginx/nginx.conf
cd /etc/nginx/sites-enabled.d/
cat << 'EOF' >> zoneminder.conf
server {
	listen  192.168.101.10:443;
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
systemctl enable --now mysqld
systemctl enable --now nginx
systemctl enable --now zoneminder
systemctl enable --now spawn-fcgi
systemctl enable --now php8.3-fpm
echo "Zoneminder get ready! Please open 192.168.101.10 in your browser"
echo "if task will be changed, you have to changed ip-address in /etc/nginx/sites-enabled.d/zoneminder.conf"
sleep 10

apt-get install cups -y
systemctl enable --now cups
mkdir -p /srv/log_print
chmod 777 /srv/log_print
sed -i "s/LogLevel warn/LogLevel debug/g" /etc/cups/cupsd.conf
echo "MaxJobs 100" >> /etc/cups/cupsd.conf
echo "AccessLog /srv/log_print/access_log" >> /etc/cups/cupsd.conf
echo "ErrorLog /srv/log_print/error_log" >> /etc/cups/cupsd.conf
echo "PageLog /srv/log_print/page_log" >> /etc/cups/cupsd.conf
systemctl restart cups
useradd -m print
echo "print:P@ssw0rd" | chpasswd
usermod -aG sys print
iptables -A INPUT -p tcp --dport 631 -j DROP
echo "CUPS get ready! Please check print settings on alterator and download needed drivers!"
sleep 10

wget https://download.cyberprotect.ru/releases/CyberBackup/16.0.28413/CyberBackup_16_64-bit.x86_64
chmod 777 CyberBackup_16_64-bit.x86_64
echo "Starting CyberBackup console!"
./CyberBackup_16_64-bit.x86_64
