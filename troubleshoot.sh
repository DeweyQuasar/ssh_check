#!/bin/bash

# Script: troubleshoot_ssh_services.sh
# Purpose: Diagnose and troubleshoot SSH/sshd services and configurations
# User Profile: Tailored for AWS Session Manager with ec2-user (requires sudo)

log_file="/home/ec2-user/troubleshoot_ssh.log"
sshd_config="/etc/ssh/sshd_config"

# Start logging
echo "Starting SSH troubleshooting at $(date)" | sudo tee "$log_file"

# Function: Check if a command exists
check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "ERROR: Command '$1' not found. Please install it using 'sudo yum install $1' or 'sudo apt install $1'." | sudo tee -a "$log_file"
        exit 1
    fi
}

# Ensure required commands exist
check_command ssh
check_command sshd
check_command nc
check_command ss
check_command iptables

# Check SSH service status
echo "Checking SSH service status..." | sudo tee -a "$log_file"
sudo systemctl is-active --quiet sshd
if [ $? -ne 0 ]; then
    echo "ERROR: sshd service is not running. Attempting to restart..." | sudo tee -a "$log_file"
    sudo systemctl restart sshd
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to restart sshd. Check system logs for more details." | sudo tee -a "$log_file"
        exit 1
    fi
    echo "INFO: sshd service restarted successfully." | sudo tee -a "$log_file"
else
    echo "INFO: sshd service is running." | sudo tee -a "$log_file"
fi

# Verify SSH configuration
echo "Checking SSH configuration for errors..." | sudo tee -a "$log_file"
sudo sshd -t
if [ $? -ne 0 ]; then
    echo "ERROR: Invalid sshd configuration. Run 'sudo sshd -t' to see specific errors." | sudo tee -a "$log_file"
    exit 1
else
    echo "INFO: sshd configuration is valid." | sudo tee -a "$log_file"
fi

# Check SSH key configurations for root, dewey, and ec2-user
for user in root dewey ec2-user; do
    echo "Checking SSH key configurations for user $user..." | sudo tee -a "$log_file"
    user_ssh_dir="/home/$user/.ssh"
    if [ -d "$user_ssh_dir" ]; then
        echo "INFO: SSH directory exists for $user at $user_ssh_dir." | sudo tee -a "$log_file"
        if [ -f "$user_ssh_dir/authorized_keys" ]; then
            echo "INFO: Found authorized_keys for $user." | sudo tee -a "$log_file"
        else
            echo "WARNING: No authorized_keys found for $user. SSH access might be restricted." | sudo tee -a "$log_file"
        fi
    else
        echo "WARNING: SSH directory does not exist for $user. SSH access might be restricted." | sudo tee -a "$log_file"
    fi
done

# Check auxiliary port configurations
echo "Checking for auxiliary SSH ports..." | sudo tee -a "$log_file"
aux_ports=$(sudo grep -E '^Port ' "$sshd_config" | awk '{print $2}')
if [ -z "$aux_ports" ]; then
    echo "INFO: No auxiliary ports configured in $sshd_config." | sudo tee -a "$log_file"
else
    echo "INFO: Auxiliary ports found: $aux_ports" | sudo tee -a "$log_file"
    for port in $aux_ports; do
        sudo ss -tuln | grep ":$port" &>/dev/null
        if [ $? -ne 0 ]; then
            echo "WARNING: Port $port is not listening. Check sshd configuration and firewall rules." | sudo tee -a "$log_file"
        else
            echo "INFO: Port $port is active and listening." | sudo tee -a "$log_file"
        fi
    done
fi

# Check firewall rules
echo "Checking firewall rules for SSH ports..." | sudo tee -a "$log_file"
sudo iptables -L | grep -E 'ACCEPT.*(ssh|22)' &>/dev/null
if [ $? -ne 0 ]; then
    echo "WARNING: SSH port 22 is not open in the firewall. Use 'sudo iptables' or 'sudo ufw' to allow it." | sudo tee -a "$log_file"
else
    echo "INFO: Firewall allows SSH traffic on port 22." | sudo tee -a "$log_file"
fi
for port in $aux_ports; do
    sudo iptables -L | grep -E "ACCEPT.*$port" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "WARNING: Auxiliary port $port is not open in the firewall. Use 'sudo iptables' or 'sudo ufw' to allow it." | sudo tee -a "$log_file"
    else
        echo "INFO: Firewall allows SSH traffic on port $port." | sudo tee -a "$log_file"
    fi
done

# Test connectivity to remote host
read -p "Enter remote host to test connectivity (or press Enter to skip): " remote_host
if [ -n "$remote_host" ]; then
    echo "Testing connectivity to $remote_host..." | sudo tee -a "$log_file"
    nc -zv "$remote_host" 22 &>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Unable to connect to $remote_host on port 22. Check network settings and remote firewall rules." | sudo tee -a "$log_file"
    else
        echo "INFO: Successfully connected to $remote_host on port 22." | sudo tee -a "$log_file"
    fi
fi

# Check SELinux status
if command -v getenforce &>/dev/null; then
    echo "Checking SELinux status..." | sudo tee -a "$log_file"
    selinux_status=$(sudo getenforce)
    if [ "$selinux_status" != "Disabled" ]; then
        echo "WARNING: SELinux is $selinux_status. Ensure SSH ports are allowed in SELinux policies." | sudo tee -a "$log_file"
    else
        echo "INFO: SELinux is disabled." | sudo tee -a "$log_file"
    fi
fi

echo "SSH troubleshooting completed. Check the log file at $log_file for details." | sudo tee -a "$log_file"
