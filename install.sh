#!/usr/bin/env bash
set -e

VMID=900
VMNAME="librechat"
STORAGE="local-lvm"
BRIDGE="vmbr0"
DISK="20G"
RAM=6144
CORES=4

TEMPLATE="debian-12-cloud"

echo "🚀 Checking Proxmox..."

if ! command -v qm &>/dev/null; then
  echo "❌ This script must run on Proxmox host"
  exit 1
fi

echo "📦 Downloading Debian Cloud Image..."

cd /var/lib/vz/template/cache

wget -q -O debian-12.qcow2 \
https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

echo "🖥 Creating VM..."

qm create $VMID \
  --name $VMNAME \
  --memory $RAM \
  --cores $CORES \
  --net0 virtio,bridge=$BRIDGE \
  --scsihw virtio-scsi-pci \
  --ostype l26 \
  --agent enabled=1

qm importdisk $VMID debian-12.qcow2 $STORAGE

qm set $VMID \
  --scsi0 $STORAGE:vm-$VMID-disk-0 \
  --boot c \
  --bootdisk scsi0 \
  --ide2 $STORAGE:cloudinit \
  --serial0 socket \
  --vga serial0 \
  --ipconfig0 ip=dhcp \
  --ciuser root

qm resize $VMID scsi0 +$DISK

qm start $VMID

echo "⏳ Waiting for VM boot..."
sleep 60

VMIP=$(qm guest cmd $VMID network-get-interfaces 2>/dev/null | grep -oP '(?<=ip-address": ")[0-9.]*' | head -1)

echo "📦 Installing Docker + LibreChat..."

ssh -o StrictHostKeyChecking=no root@$VMIP << 'EOF'

apt update && apt install -y curl git

curl -fsSL https://get.docker.com | sh

mkdir -p /opt/librechat
cd /opt/librechat

cat <<EOC > docker-compose.yml
version: "3.8"

services:
  mongo:
    image: mongo:7
    restart: always
    volumes:
      - mongo_data:/data/db

  librechat:
    image: ghcr.io/danny-avila/librechat:latest
    ports:
      - "3080:3080"
    environment:
      - MONGO_URI=mongodb://mongo:27017/librechat
    depends_on:
      - mongo

volumes:
  mongo_data:
EOC

docker compose up -d
EOF

echo "✅ DONE!"
echo "🌐 LibreChat: http://$VMIP:3080"
