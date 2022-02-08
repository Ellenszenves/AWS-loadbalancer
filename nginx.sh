#!/bin/bash
sudo apt-get update
sudo apt-get install -y nginx
#/etc/nginx/sites-enabled/default
sudo sed -i 's/listen 80 default_server;/listen 3000 default_server;/' /etc/nginx/sites-enabled/default
sudo sed -i 's/listen [::]:80 default_server;/listen [::]:80 default_server;/' /etc/nginx/sites-enabled/default
#/var/www/html/index.nginx-debian.html
sudo sed -i 's/Welcome to nginx/Welcome to 1/' /var/www/html/index.nginx-debian.html
sudo systemctl restart nginx