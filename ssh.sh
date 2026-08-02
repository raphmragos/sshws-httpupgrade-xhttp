#!/bin/bash

# 📌 Your Settings
USERNAME="virgozki"
PASSWORD="virgozki"
REGION="us-central1"
SERVICE_NAME="virgozki"
WSPATH="/Virgozki-Ws"
HTTPUPGRADE_PATH="/Virgozki-HttpUpgrade"
XHTTP_PATH="/Virgozki-Xhttp"
DOMAIN="www.google.com"
BUG_HOST="www.google.com"

# 📁 Create working folder
mkdir -p ~/virgozki && cd ~/virgozki

# ⚙️ Xray Config: SSH WS + SSH HTTPUpgrade + SSH XHTTP
cat <<EOF > config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "ssh",
      "settings": {
        "users": [
          {
            "username": "$USERNAME",
            "password": "$PASSWORD"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$WSPATH",
          "host": "$BUG_HOST"
        }
      }
    },
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "ssh",
      "settings": {
        "users": [
          {
            "username": "$USERNAME",
            "password": "$PASSWORD"
          }
        ]
      },
      "streamSettings": {
        "network": "httpupgrade",
        "httpupgradeSettings": {
          "path": "$HTTPUPGRADE_PATH",
          "host": "$BUG_HOST"
        }
      }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "ssh",
      "settings": {
        "users": [
          {
            "username": "$USERNAME",
            "password": "$PASSWORD"
          }
        ]
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "$XHTTP_PATH",
          "host": "$BUG_HOST",
          "mode": "packet-up"
        }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "tag": "direct" } ]
}
EOF

# 🌐 Nginx Config (Optimized for Cloud Run)
cat <<EOF > nginx.conf
worker_processes auto;
worker_rlimit_nofile 65535;
events {
    worker_connections 65535;
    multi_accept on;
}
http {
    sendfile on;
    keepalive_timeout 300;
    keepalive_requests 1000;

    server {
        listen 8080;
        server_name _;

        # Fallback page
        location / {
            proxy_pass https://$DOMAIN;
            proxy_set_header Host $DOMAIN;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_buffering off;
        }

        # SSH WebSocket
        location $WSPATH {
            proxy_pass http://127.0.0.1:10000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $BUG_HOST;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_buffering off;
            proxy_read_timeout 86400;
        }

        # SSH HTTPUpgrade
        location $HTTPUPGRADE_PATH {
            proxy_pass http://127.0.0.1:10001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $BUG_HOST;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_cache_bypass \$http_upgrade;
            proxy_buffering off;
            proxy_read_timeout 86400;
        }

        # SSH XHTTP
        location $XHTTP_PATH {
            proxy_pass http://127.0.0.1:10002;
            proxy_http_version 1.1;
            proxy_set_header Host $BUG_HOST;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_buffering off;
            proxy_read_timeout 86400;
        }
    }
}
EOF

# 🐳 Dockerfile (Fixed startup order)
cat <<EOF > Dockerfile
FROM teddysun/xray:latest AS xray-bin
FROM openresty/openresty:alpine-fat

# Copy Xray binary
COPY --from=xray-bin /usr/bin/xray /usr/local/bin/xray

# Copy config files
COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Expose port
EXPOSE 8080

# Start services properly
CMD ["/bin/sh", "-c", "/usr/local/bin/xray run -c /etc/xray.json & /usr/local/openresty/bin/openresty -g 'daemon off;'"]
EOF

# 🚀 Deploy to Google Cloud Run (Complete command)
gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --port 8080 \
  --timeout=3600 \
  --concurrency=80

