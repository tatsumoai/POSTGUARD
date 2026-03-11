# 03 - Firewall Configuration

## Purpose
Block all incoming traffic except the ports your application needs. Default deny is the foundation of server security.

## Steps

### 1. Allow Required Ports BEFORE Enabling
```bash
sudo ufw allow 22    # SSH (MUST be first, or you lock yourself out)
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
```

### 2. Enable the Firewall
```bash
sudo ufw enable
# Type 'y' to confirm
```

### 3. Verify
```bash
sudo ufw status verbose
```

Expected output:
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22                         ALLOW IN    Anywhere
80                         ALLOW IN    Anywhere
443                        ALLOW IN    Anywhere
```

### Common Operations
```bash
# Temporarily open a port (e.g., for dev server)
sudo ufw allow 8000

# Close it when done
sudo ufw delete allow 8000

# Block a specific port explicitly
sudo ufw deny 3306    # Block MySQL from outside
```

## Why This Matters
- "Default deny incoming" means every port is blocked unless explicitly opened.
- MySQL (3306) stays blocked from external access. Only reachable from the server itself (localhost).
- CRITICAL: Always allow port 22 BEFORE enabling the firewall. If you enable ufw without allowing SSH, you are permanently locked out of the server.
