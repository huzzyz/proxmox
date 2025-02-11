#!/bin/bash

# Ensure the script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Prompt for the new hostname
read -p "Enter new hostname: " NEW_HOSTNAME

# Validate input is not empty
if [ -z "$NEW_HOSTNAME" ]; then
    echo "Hostname cannot be empty"
    exit 1
fi

# Set the hostname using hostnamectl
hostnamectl set-hostname "$NEW_HOSTNAME"
if [ $? -ne 0 ]; then
    echo "Failed to set hostname. Exiting."
    exit 1
fi

# Update /etc/hosts file
if [ ! -f /etc/hosts ]; then
    # Create a new /etc/hosts file if it doesn't exist
    cat <<EOF > /etc/hosts
127.0.0.1	localhost
127.0.1.1	$NEW_HOSTNAME
EOF
    echo "Created new hosts file with entries."
else
    # Update or add the 127.0.1.1 entry
    if grep -q "^127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*$/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
        echo "Modified existing 127.0.1.1 entry in hosts file."
    else
        echo -e "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
        echo "Added new 127.0.1.1 entry to hosts file."
    fi

    # Ensure the localhost entry exists; add it if missing
    if ! grep -q "^127.0.0.1.*localhost" /etc/hosts; then
        sed -i "1i127.0.0.1\tlocalhost" /etc/hosts
        echo "Added localhost entry to hosts file."
    fi
fi

echo "Hostname has been set to $NEW_HOSTNAME"
echo "Current /etc/hosts file contents:"
cat /etc/hosts

# Start a new shell session to apply changes
exec bash
