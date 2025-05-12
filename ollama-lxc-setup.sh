#!/bin/bash
set -e

# Use already-downloaded template
TEMPLATE_FILE="/var/lib/vz/template/cache/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"

# CONFIGURABLE PARAMETERS
LXC_ID=190
LXC_NAME=ollama
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
  --rootfs local-lvm:${DISK_GB} \
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

echo "[+] Running Ollama + WebUI install inside container..."
pct exec $LXC_ID -- bash -c "$(curl -fsSL https://i.kalimi.net/ollama-cpu.sh)"

echo "[+] Pulling model: $MODEL_NAME..."
pct exec $LXC_ID -- bash -c "ollama pull $MODEL_NAME"

IP=$(pct exec $LXC_ID -- hostname -I | awk '{print $1}')
echo "[✅] Done! Access Open WebUI at: http://$IP:3000"
echo "[i] LXC Login: pct console $LXC_ID  (password: ollama123)"