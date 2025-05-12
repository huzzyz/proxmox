#!/bin/bash
set -e

# CONFIGURABLE SETTINGS
LXC_ID=190
LXC_NAME=ollama
STORAGE_POOL="local-zfs"   # Change if your ZFS pool is named differently
TEMPLATE_FILE="/var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
MEM_MB=8192
CORES=4
DISK_GB=32
BRIDGE="vmbr0"
MODEL_NAME="mistral"

echo "[+] Creating LXC container $LXC_NAME ($LXC_ID)..."
pct create $LXC_ID "$TEMPLATE_FILE" \
  --hostname $LXC_NAME \
  --cores $CORES \
  --memory $MEM_MB \
  --rootfs ${STORAGE_POOL}:${DISK_GB} \
  --net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  --unprivileged 0 \
  --features nesting=1,keyctl=1,fuse=1 \
  --ostype ubuntu \
  --startup order=20 \
  --onboot 1 \
  --password ollama123 \
  --nameserver 1.1.1.1

echo "[+] Starting container..."
pct start $LXC_ID
sleep 5

echo "[+] Installing Ollama + Open WebUI inside the container..."
pct exec $LXC_ID -- bash -c '
set -e
apt update && apt install -y curl sudo gnupg2 ca-certificates apt-transport-https software-properties-common

echo "[+] Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "[+] Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

echo "[+] Creating Ollama systemd service..."
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

echo "[+] Launching Open WebUI..."
docker run -d \
  --name open-webui \
  -p 3000:3000 \
  -v open-webui-data:/app/backend/data \
  -v /var/run/ollama:/var/run/ollama \
  --add-host host.docker.internal:host-gateway \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:main
'

echo "[+] Pulling default model: $MODEL_NAME..."
pct exec $LXC_ID -- bash -c "ollama pull $MODEL_NAME"

IP=$(pct exec $LXC_ID -- hostname -I | awk '{print $1}')
echo "[✅] Ollama + WebUI setup complete!"
echo "Access Open WebUI at: http://$IP:3000"
echo "LXC Login: pct console $LXC_ID (password: ollama123)"