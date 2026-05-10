#!/usr/bin/env bash
set -e

VMID=900
VMNAME="librechat"
STORAGE="local-lvm"
BRIDGE="vmbr0"
DISK="20G"
RAM=6144
CORES=4

echo "🚀 Creating LibreChat VM..."

# Debian Cloud Image
wget -q https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 -O /var/lib/vz/template/iso/debian12.qcow2

qm create $VMID \
  --name $VMNAME \
  --memory $RAM \
  --cores $CORES \
  --net0 virtio,bridge=$BRIDGE \
  --scsihw virtio-scsi-pci \
  --ostype l26

qm importdisk $VMID /var/lib/vz/template/iso/debian12.qcow2 $STORAGE

qm set $VMID \
  --scsi0 $STORAGE:vm-$VMID-disk-0 \
  --boot c \
  --bootdisk scsi0 \
  --ide2 $STORAGE:cloudinit \
  --serial0 socket \
  --vga serial0 \
  --ipconfig0 ip=dhcp \
  --ciuser root \
  --cicustom "user=local:snippets/cloud-init.yaml"

qm resize $VMID scsi0 +$DISK

qm start $VMID

echo "✅ VM erstellt!"
echo "👉 LibreChat startet automatisch nach Boot"
