#!/bin/bash

# Drone CI Server setup

set -x

export DEBIAN_FRONTEND=noninteractive
apt update

# Certbot/SSL
apt-get install software-properties-common -y
add-apt-repository universe -y
add-apt-repository ppa:certbot/certbot -y
apt-get install certbot python3-certbot-dns-route53 -y
certbot certonly --dns-route53 -d ${VPN_SERVER_HOST} --agree-tos -m ${ADMIN_EMAIL} -n

# Nginx config
apt-get install nginx -y
rm -f /etc/nginx/sites-enabled/default
openssl dhparam -out /etc/ssl/certs/dhparam.pem -2 2048
cat << EOF > /etc/nginx/conf.d/ssl.conf
## SSL Certs are referenced in the actual Nginx config per-vhost
# Disable insecure SSL v2. Also disable SSLv3, as TLS 1.0 suffers a downgrade attack, allowing an attacker to force a connection to use SSLv3 and therefore disable forward secrecy.
# ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
# Strong ciphers for PFS
ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
# Use server's preferred cipher, not the client's
# ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:10m;
# Use ephemeral 4096 bit DH key for PFS
ssl_dhparam /etc/ssl/certs/dhparam.pem;
# Use OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
# Enable HTTP Strict Transport
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
add_header X-Frame-Options "DENY";
EOF
cat << EOF > /etc/nginx/sites-enabled/${VPN_SERVER_HOST}.conf
# Redirect inbound http to https
server {
    listen 80 default_server;
    server_name ${VPN_SERVER_HOST};
    return 301 https://${VPN_SERVER_HOST}\$request_uri;
}

# Load SSL configs and serve SSL site
server {
    listen 443 ssl;
    server_name ${VPN_SERVER_HOST};
    error_log /var/log/nginx/${VPN_SERVER_HOST}-error.log warn;
    access_log /var/log/nginx/${VPN_SERVER_HOST}-access.log;
    client_body_in_file_only clean;
    client_body_buffer_size 32K;
    # set max upload size
    client_max_body_size 8M;
    sendfile on;
    send_timeout 600s;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_buffering off;
        chunked_transfer_encoding off;
    }

    include conf.d/ssl.conf;
    ssl_certificate /etc/letsencrypt/live/${VPN_SERVER_HOST}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${VPN_SERVER_HOST}/privkey.pem;
}
EOF
systemctl enable nginx
systemctl restart nginx

# Docker install
apt-get remove docker docker-engine docker.io containerd runc -y
apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io docker-compose -y
systemctl enable docker
systemctl start docker

docker run \
  --restart=always \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun:/dev/net/tun \
  --volume=/opt/wireguard:/data \
  --env=ADMIN_USERNAME=${VPN_ADMIN_USER} \
  --env=ADMIN_PASSWORD=${VPN_ADMIN_PASSWORD} \
  --env=UPSTREAM_DNS=${UPSTREAM_DNS} \
  --publish=8000:8000/tcp \
  --publish=51820:51820/udp \
  --detach=true \
  --name=wireguard \
  place1/wg-access-server


# Install awscli
apt-get install awscli -y

# Update DNS for individual node
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
cat << EOF > update-${VPN_SERVER_HOST}.json
{
    "Comment": "Update record to reflect new IP address of VPN",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "${VPN_SERVER_HOST}.",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$PUBLIC_IP"
                    }
                ]
            }
        }
    ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://update-${VPN_SERVER_HOST}.json
