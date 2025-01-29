#!/bin/bash

# Script to make a Proxmox bridge VLAN-aware and restore static IP configuration
set -e

# Function to list available bridges
list_bridges() {
    echo "Available bridges:"
    bridges=$(brctl show | awk 'NR>1 {print $1}' | sort | uniq)
    echo "$bridges"
}

# Function to list available interfaces
list_interfaces() {
    echo "Available network interfaces:"
    interfaces=$(ip link show | awk -F: '$0 !~ "lo|vir|docker|^[^0-9]"{print $2;getline}' | tr -d ' ')
    echo "$interfaces"
}

# Detect and display available bridges
echo "Detecting available bridges..."
list_bridges

# Ensure user input is captured even with 'curl | sh'
echo -n "Enter the name of the bridge you want to make VLAN-aware (e.g., vmbr0): "
read -r BRIDGE_NAME

# Validate bridge name
if ! brctl show | grep -q "^$BRIDGE_NAME"; then
    echo "Error: Bridge '$BRIDGE_NAME' not found."
    exit 1
fi

# Detect and display available interfaces
echo "Detecting available network interfaces..."
list_interfaces

# Prompt user for network interface
echo -n "Enter the physical network interface to attach to the bridge (e.g., enp0s31f6): "
read -r INTERFACE

# Validate interface name
if ! ip link show "$INTERFACE" &> /dev/null; then
    echo "Error: Network interface '$INTERFACE' not found."
    exit 1
fi

# Prompt user for static IP configuration
echo -n "Enter the static IP address for the bridge (e.g., 192.168.1.100): "
read -r STATIC_IP

echo -n "Enter the subnet mask (e.g., 255.255.255.0): "
read -r SUBNET_MASK

echo -n "Enter the default gateway (e.g., 192.168.1.1): "
read -r GATEWAY

# Backup existing configuration
CONFIG_FILE="/etc/network/interfaces"
BACKUP_FILE="/etc/network/interfaces.backup.$(date +%F_%T)"
echo "Backing up $CONFIG_FILE to $BACKUP_FILE..."
cp $CONFIG_FILE $BACKUP_FILE

# Update the configuration
echo "Updating $CONFIG_FILE to make $BRIDGE_NAME VLAN-aware and restore static IP..."
cat <<EOF > $CONFIG_FILE
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet manual

auto $BRIDGE_NAME
iface $BRIDGE_NAME inet static
    address $STATIC_IP
    netmask $SUBNET_MASK
    gateway $GATEWAY
    bridge-ports $INTERFACE
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
EOF

# Restart networking
echo "Restarting networking service..."
systemctl restart networking

# Confirm changes
echo "Configuration applied! The bridge '$BRIDGE_NAME' is now VLAN-aware with:"
echo "  - Static IP: $STATIC_IP"
echo "  - Subnet Mask: $SUBNET_MASK"
echo "  - Gateway: $GATEWAY"
