#!/bin/bash
set -e

# Set hostname
sudo hostnamectl set-hostname ${hostname}

# Reverce proxy installation
# https://www.jenkins.io/doc/book/system-administration/reverse-proxy-configuration-with-jenkins/reverse-proxy-configuration-nginx/
sudo apt-get update
sudo apt-get install -y nginx

sudo tee /etc/nginx/sites-available/jenkins <<EOF
upstream jenkins {
  keepalive 32; # keepalive connections
  server ${master_private_ip}:32000; # jenkins ip and port
}

upstream flask {
  server ${master_private_ip}:32001; # flask ip and port
}

upstream grafana {
  server ${master_private_ip}:32004; # grafana ip and port
}

# Required for Jenkins websocket agents
map \$http_upgrade \$connection_upgrade {
  default upgrade;
  '' close;
}

server {
  listen          80;       # Listen on port 80 for IPv4 requests

  server_name     _;  # accept any server name

  access_log      /var/log/nginx/jenkins.access.log;
  error_log       /var/log/nginx/jenkins.error.log;

  # pass through headers from Jenkins that Nginx considers invalid
  ignore_invalid_headers off;

  location ~ "^\/static\/[0-9a-fA-F]{8}\/(.*)$" {
    # rewrite all static files into requests to the root
    # E.g /static/12345678/css/something.css will become /css/something.css
    rewrite "^\/static\/[0-9a-fA-F]{8}\/(.*)" /\$1 last;
  }

  location /userContent {
    # have nginx handle all the static requests to userContent folder
    # note : This is the \$JENKINS_HOME dir
    root /var/lib/jenkins/;
    if (!-f \$request_filename){
      # this file does not exist, might be a directory or a /**view** url
      rewrite (.*) /\$1 last;
      break;
    }
    sendfile on;
  }

  location /flask/ {
      proxy_pass         http://flask/;
      proxy_set_header   Host              \$http_host;
      proxy_set_header   X-Real-IP         \$remote_addr;
      proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto \$scheme;
  }

  location /grafana/ {
      proxy_pass         http://grafana;
      proxy_set_header   Host              \$http_host;
      proxy_set_header   X-Real-IP         \$remote_addr;
      proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto \$scheme;
      proxy_set_header   X-Forwarded-Host  \$http_host;
      proxy_set_header   X-Forwarded-Port  \$server_port;
  }

  location / {
      sendfile off;
      proxy_pass         http://jenkins;
      proxy_http_version 1.1;

      # Required for Jenkins websocket agents
      proxy_set_header   Connection        \$connection_upgrade;
      proxy_set_header   Upgrade           \$http_upgrade;

      proxy_set_header   Host              \$http_host;
      proxy_set_header   X-Real-IP         \$remote_addr;
      proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto \$scheme;
      proxy_set_header   X-Forwarded-Host  \$http_host;
      proxy_set_header   X-Forwarded-Port  \$server_port;
      proxy_max_temp_file_size 0;

      #this is the maximum upload size
      client_max_body_size       10m;
      client_body_buffer_size    128k;

      proxy_connect_timeout      90;
      proxy_send_timeout         90;
      proxy_read_timeout         90;
      proxy_request_buffering    off; # Required for HTTP CLI commands
  }

}
EOF

sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl enable nginx
sudo systemctl restart nginx

# Kubectl installation
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl