# 04 - Nginx Setup

## Purpose
Configure nginx as a reverse proxy for the Laravel application. Nginx handles incoming HTTP/HTTPS requests and forwards PHP requests to PHP-FPM for processing.

## Steps

### 1. Install Nginx
```bash
sudo apt install nginx -y
sudo systemctl status nginx    # Should show "active (running)"
```

### 2. Handle Apache Conflict
PHP installation may pull in Apache as a dependency. If Apache is running, it steals port 80 from nginx.
```bash
sudo systemctl stop apache2
sudo systemctl disable apache2
sudo systemctl restart nginx
```

### 3. Create Site Configuration
```bash
sudo nano /etc/nginx/sites-available/postguard
```

Content:
```nginx
server {
    listen 80;
    server_name postg.app;
    root /home/arthur/postguard/public;

    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### 4. Enable the Site
```bash
# Remove the default site
sudo rm /etc/nginx/sites-enabled/default

# Symlink your config
sudo ln -s /etc/nginx/sites-available/postguard /etc/nginx/sites-enabled/

# Test config syntax
sudo nginx -t

# Restart
sudo systemctl restart nginx
```

### 5. Fix Permissions
Nginx runs as `www-data` and needs to traverse into the user's home directory and write to Laravel's storage:
```bash
sudo chmod o+x /home/arthur
sudo chown -R www-data:www-data /home/arthur/postguard/storage
sudo chown -R www-data:www-data /home/arthur/postguard/bootstrap/cache
sudo chmod -R 775 /home/arthur/postguard/storage
sudo chmod -R 775 /home/arthur/postguard/bootstrap/cache
```

## Configuration Explained
- `root /home/arthur/postguard/public` - Laravel's public directory is the web root, not the project root
- `try_files $uri $uri/ /index.php?$query_string` - sends all requests through Laravel's front controller
- `fastcgi_pass unix:/run/php/php8.3-fpm.sock` - forwards PHP to PHP-FPM via Unix socket
- `location ~ /\.` - blocks access to hidden files (.env, .git, etc.)

## Troubleshooting
- **502 Bad Gateway** - PHP-FPM is not running. Install and start it: `sudo apt install php8.3-fpm -y`
- **403 Forbidden** - permission issue. Check `sudo chmod o+x /home/arthur`
- **"File not found"** - same permission issue, or wrong `root` path in config
- **Still seeing Apache** - hard refresh (Ctrl+Shift+R) or check `sudo systemctl status apache2`
