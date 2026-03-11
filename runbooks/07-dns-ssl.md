# 07 - DNS and SSL

## Purpose
Point a domain at the server and install a free SSL certificate for HTTPS. This covers DNS configuration and SSL certificate management.

## Steps

### 1. Purchase Domain
Purchased `postg.app` from Porkbun ($10/year).

### 2. Configure DNS (DigitalOcean)
Changed nameservers at Porkbun from default to:
```
ns1.digitalocean.com
ns2.digitalocean.com
ns3.digitalocean.com
```

In DigitalOcean Networking > Domains, added `postg.app` with:
- **A record:** `@` pointing to `142.93.113.189` (TTL 3600)

### 3. Verify DNS Propagation
```bash
# From local machine
nslookup postg.app
# Should return 142.93.113.189
```

DNS propagated in under 5 minutes with DigitalOcean nameservers.

### 4. Update Nginx Config
```bash
sudo sed -i 's/server_name 142.93.113.189/server_name postg.app/' /etc/nginx/sites-available/postguard
sudo nginx -t
sudo systemctl restart nginx
```

### 5. Install Certbot and Get SSL Certificate
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d postg.app
```

Certbot will:
- Ask for your email (for renewal notices)
- Ask you to agree to terms of service
- Automatically configure nginx for SSL
- Set up auto-renewal via systemd timer

### 6. Verify SSL
Visit `https://postg.app` in a browser. Should show a lock icon.

### 7. Test Auto-Renewal
```bash
sudo certbot renew --dry-run
```

## DNS Record Types Reference
- **A record:** maps domain to IPv4 address (postg.app -> 142.93.113.189)
- **AAAA record:** maps domain to IPv6 address
- **CNAME record:** alias pointing to another domain (www.postg.app -> postg.app)
- **MX record:** mail server for the domain
- **TXT record:** arbitrary text (SPF, DKIM, domain verification)
- **NS record:** nameservers for the domain
- **TTL:** time-to-live, how long resolvers cache the record (in seconds)

## SSL/TLS Key Concepts
- **Let's Encrypt:** free, automated SSL certificates. Auto-renews every 90 days.
- **Certbot:** CLI tool that obtains and renews Let's Encrypt certificates.
- **Certificate chain:** your cert -> intermediate CA -> root CA. All three must be served correctly.
- **Common issues:** expired cert, mismatched domain, incomplete chain, mixed content (HTTP resources on HTTPS page).

## What Certbot Changed in Nginx Config
After running certbot, it automatically modified `/etc/nginx/sites-available/postguard` to:
- Listen on port 443 with SSL
- Reference the certificate and key files in `/etc/letsencrypt/live/postg.app/`
- Add a redirect from HTTP (port 80) to HTTPS (port 443)
- Configure SSL protocols and ciphers

## Important Notes
- If using Cloudflare as DNS, set the proxy status to "DNS only" (grey cloud) during certbot setup. Cloudflare's proxy can interfere with SSL verification.
- `.app` domains require HTTPS. Google enforces HSTS preloading for all .app TLDs.
- Let's Encrypt rate limits: 50 certificates per domain per week. Not an issue for normal use, but don't run certbot repeatedly during testing.
