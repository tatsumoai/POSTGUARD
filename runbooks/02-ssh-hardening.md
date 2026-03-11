# 02 - SSH Hardening

## Purpose
Lock down SSH to prevent brute force attacks and unauthorized access. These are the first two changes any sysadmin makes on a new server.

## Steps

### 1. Edit SSH Config
```bash
sudo nano /etc/ssh/sshd_config
```

### 2. Disable Root Login
Find `PermitRootLogin` and change to:
```
PermitRootLogin no
```
Remove the `#` if the line is commented out.

### 3. Disable Password Authentication
Find `PasswordAuthentication` (use Ctrl+W to search in nano) and change to:
```
PasswordAuthentication no
```
Remove the `#` if the line is commented out.

### 4. Save and Restart
```bash
# Save: Ctrl+O, Enter. Exit: Ctrl+X
sudo systemctl restart sshd
```

### 5. Verify
```bash
# Check the config took effect
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config

# Expected output (ignore commented lines starting with #):
# PermitRootLogin no
# PasswordAuthentication no

# Test root is blocked (from a new local terminal)
ssh root@YOUR_IP
# Expected: "Permission denied (publickey)"
```

## Why This Matters
- Root login is the #1 target for brute force attacks on public servers.
- Password auth is vulnerable to brute force. SSH key auth makes brute force effectively impossible since the attacker would need your private key file.
- Always keep an existing SSH session open while changing SSH config. If something breaks, that session is your lifeline.
