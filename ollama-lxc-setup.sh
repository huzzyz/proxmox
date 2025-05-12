#!/bin/bash
set -e

echo "[+] Updating container..."
apt update && apt install -y curl sudo gnupg2 apt-transport-https ca-certificates software-properties-common

echo "[+] Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "[+] Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

echo "[+] Creating systemd service for Ollama..."
cat <<EOF > /etc/systemd/system/ollama.service
[Unit]
Description=Ollama API Server
After=network.target

[Service]
ExecStart=/usr/local/bin/ollama serve
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now ollama

echo "[+] Starting Open WebUI container..."
docker run -d \
  --name open-webui \
  -p 3000:3000 \
  -v open-webui-data:/app/backend/data \
  -v /var/run/ollama:/var/run/ollama \
  --add-host host.docker.internal:host-gateway \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:main

echo "[✅] Setup complete. Access Open WebUI on port 3000."