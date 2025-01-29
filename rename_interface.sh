#!/bin/bash

# Script to rename a network interface on an Ubuntu VM interactively
set -e

# Function to list available network interfaces
list_interfaces() {
    echo "Available network interfaces:"
    interfaces=$(ip link show | awk -F: '$0 !~ "lo|vir|docker|^[^0-9]"{print $2;getline}' | tr -d ' ')
    echo "$interfaces"
}

# Detect network interfaces
echo "Detecting available network interfaces..."
list_interfaces

# Prompt user to select the interface to rename
read -p "Enter the current name of the network interface you want to rename: " OLD_INTERFACE

# Validate interface name
if ! ip link show "$OLD_INTERFACE" &> /dev/null; then
    echo "Error: Network interface '$OLD_INTERFACE' not found."
    exit 1
fi

# Prompt user for the new interface name
read -p "Enter the new name for the interface (e.g., eth0): " NEW_INTERFACE

# Check if the new name already exists
if ip link show "$NEW_INTERFACE" &> /dev/null; then
    echo "Error: The interface name '$NEW_INTERFACE' already exists. Choose a different name."
    exit 1
fi

# Get the MAC address of the old interface
MAC_ADDRESS=$(ip link show "$OLD_INTERFACE" | awk '/link\/ether/ {print $2}')

# Create a udev rule to persistently rename the interface
UDEV_RULES_FILE="/etc/udev/rules.d/70-persistent-net.rules"
echo "Creating udev rule to rename '$OLD_INTERFACE' to '$NEW_INTERFACE'..."
echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC_ADDRESS\", NAME=\"$NEW_INTERFACE\"" | sudo tee $UDEV_RULES_FILE

# Check if Netplan is being used
NETPLAN_FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -n 1)
if [[ -f "$NETPLAN_FILE" ]]; then
    echo "Netplan detected. Updating configuration..."
    sudo sed -i "s/$OLD_INTERFACE/$NEW_INTERFACE/g" "$NETPLAN_FILE"
    
    # Apply Netplan changes
    echo "Applying Netplan configuration..."
    sudo netplan apply
else
    echo "No Netplan configuration found. Skipping Netplan update."
fi

# Reboot the system to apply the new interface name
echo "Rebooting the system to finalize interface renaming..."
sudo reboot
