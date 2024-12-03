#!/bin/bash
# Script to perform a full audit of SSH configuration and keys on a system

# Ensure the script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo."
    exit 1
fi

echo "Starting comprehensive SSH audit..."

# Check SSH configuration files
echo "Checking SSH configuration files..."
for config_file in /etc/ssh/sshd_config /etc/ssh/ssh_config; do
    if [ -f "$config_file" ]; then
        echo "Contents of $config_file:"
        cat "$config_file"
        echo "Permissions of $config_file:"
        ls -l "$config_file"
        echo
    else
        echo "$config_file does not exist."
        echo
    fi
done

# Check SSH known hosts
echo "Checking SSH known hosts files..."
for known_hosts in /etc/ssh/ssh_known_hosts ~/.ssh/known_hosts; do
    if [ -f "$known_hosts" ]; then
        echo "Contents of $known_hosts:"
        cat "$known_hosts"
        echo "Permissions of $known_hosts:"
        ls -l "$known_hosts"
        echo
    else
        echo "$known_hosts does not exist."
        echo
    fi
done

# Check SSH key files
echo "Checking SSH key files..."
ssh_key_directories=(/etc/ssh /root/.ssh /home/*/.ssh)
for dir in "${ssh_key_directories[@]}"; do
    if [ -d "$dir" ]; then
        echo "Listing SSH key files in $dir:"
        find "$dir" -type f -name '*.pub' -or -name 'id_*' | while read -r key_file; do
            echo "Key file: $key_file"
            echo "Permissions of $key_file:"
            ls -l "$key_file"
            echo
        done
    else
        echo "$dir does not exist."
        echo
    fi
done

# Check the permissions of the .ssh directories
echo "Checking permissions of .ssh directories..."
for dir in /root/.ssh /home/*/.ssh; do
    if [ -d "$dir" ]; then
        echo "Permissions of $dir:"
        ls -ld "$dir"
        echo
    else
        echo "$dir does not exist."
        echo
    fi
done

# Check SSH Daemon settings in systemd (if applicable)
echo "Checking systemd SSH daemon configuration..."
if systemctl is-enabled sshd 2>/dev/null; then
    echo "SSHD service status:"
    systemctl status sshd
    echo "SSHD service configuration:"
    systemctl cat sshd | cat
    echo
else
    echo "SSHD service is not enabled."
    echo
fi

# Check for SSH agent
echo "Checking SSH agent status..."
if pgrep -x "ssh-agent" > /dev/null; then
    echo "SSH agent is running."
else
    echo "SSH agent is not running."
fi
echo

# Check SSH login banners and restrictions
echo "Checking login banners and restrictions..."
banner_files=(/etc/issue /etc/issue.net /etc/motd)
for banner in "${banner_files[@]}"; do
    if [ -f "$banner" ]; then
        echo "Contents of $banner:"
        cat "$banner"
        echo
    else
        echo "$banner does not exist."
        echo
    fi
done

# Verify SSH service listening on expected port
echo "Verifying SSH service is listening on expected ports..."
ss -tuln | grep ':22'

# Check user and group permissions related to SSH
echo "Checking user and group permissions for SSH..."
getent passwd | while IFS=: read -r user _ _ _ _ _; do
    if [ -d "/home/$user" ] || [ "$user" == "root" ]; then
        echo "User $user has the following permissions in their .ssh directory:"
        ls -ld /home/$user/.ssh 2>/dev/null || echo ".ssh directory for $user does not exist."
    fi
done

# Provide a final report summary
echo "SSH audit complete."