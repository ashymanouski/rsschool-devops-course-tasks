#!/bin/bash
# Ensure ubuntu user exists and has proper SSH access
if ! id -u ubuntu >/dev/null 2>&1; then
    useradd -m -s /bin/bash ubuntu
    usermod -aG sudo ubuntu
fi

# Create .ssh directory for ubuntu user
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

# Copy authorized_keys from ec2-user to ubuntu user
if [ -f /home/ec2-user/.ssh/authorized_keys ]; then
    cp /home/ec2-user/.ssh/authorized_keys /home/ubuntu/.ssh/authorized_keys
fi

# Set proper ownership and permissions
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys