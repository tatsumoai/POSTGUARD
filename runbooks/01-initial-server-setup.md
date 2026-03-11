# 01 - Initial Server Setup

## Purpose
Provision a fresh Ubuntu server and create a non-root user with sudo access. Never work as root in production.

## Steps

### 1. Create Droplet
- Provider: DigitalOcean
- OS: Ubuntu 24.04 LTS
- Plan: Basic, Regular SSD, $6/month (1 vCPU, 1GB RAM, 25GB SSD)
- Region: NYC1
- Auth: SSH key (generated locally with `ssh-keygen -t ed25519`)

### 2. Generate SSH Key (local machine, PowerShell)
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
cat ~/.ssh/id_ed25519.pub
# Copy the output and paste into DigitalOcean's SSH key field
```

### 3. SSH In As Root
```bash
ssh root@YOUR_IP
```

### 4. Create Non-Root User
```bash
adduser arthur
# Set password when prompted (characters won't display)
# Skip the optional fields (Full Name, etc.)

usermod -aG sudo arthur
```

### 5. Copy SSH Key to New User
```bash
mkdir -p /home/arthur/.ssh
cp /root/.ssh/authorized_keys /home/arthur/.ssh/authorized_keys
chown -R arthur:arthur /home/arthur/.ssh
chmod 700 /home/arthur/.ssh
chmod 600 /home/arthur/.ssh/authorized_keys
```

### 6. Test Login (from a NEW local terminal, keep root session open)
```bash
ssh arthur@YOUR_IP
```

### 7. Update System
```bash
sudo apt update && sudo apt upgrade -y
```
When prompted about modified config files during upgrade, choose "keep the local version" to preserve any changes you've made.

## Why This Matters
- Root has unlimited access. A single mistake can destroy the server.
- sudo forces deliberate privilege escalation for admin tasks.
- SSH key permissions must be exact (700/600) or SSH silently refuses the key.
- Always test the new user login before closing the root session.
