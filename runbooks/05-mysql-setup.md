# 05 - MySQL Setup

## Purpose
Install MySQL, create a dedicated database and user with least-privilege access for the application.

## Steps

### 1. Install MySQL
```bash
sudo apt install mysql-server -y
```

### 2. Run Security Script
```bash
sudo mysql_secure_installation
```
- VALIDATE PASSWORD component: `n` (not needed for dev)
- Set root password: choose something memorable
- Remove anonymous users: `y`
- Disallow root login remotely: `y`
- Remove test database: `y`
- Reload privilege tables: `y`

### 3. Create Database and User
```bash
sudo mysql
```

```sql
CREATE DATABASE postguard;
CREATE USER 'postguard'@'localhost' IDENTIFIED BY 'YourPasswordHere';
GRANT ALL PRIVILEGES ON postguard.* TO 'postguard'@'localhost';
FLUSH PRIVILEGES;
SHOW DATABASES;
exit
```

### 4. Configure Laravel
In `/home/arthur/postguard/.env`:
```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=postguard
DB_USERNAME=postguard
DB_PASSWORD=YourPasswordHere
```

### 5. Run Migrations
```bash
cd ~/postguard
php artisan migrate
```

## Key Concepts

### Least Privilege
The `postguard` user can ONLY access the `postguard` database. It cannot read, modify, or drop any other database on the server. If the app is compromised, the blast radius is limited to its own data.

### localhost Only
`'postguard'@'localhost'` means this user can only connect from the server itself. Combined with UFW blocking port 3306 from outside, MySQL is completely inaccessible from the internet.

### InnoDB vs MyISAM
- **InnoDB** (default): supports transactions, foreign keys, row-level locking, crash recovery. Use for everything.
- **MyISAM** (legacy): no transactions, no foreign keys, table-level locking. Rarely used in new projects.

## Useful Commands
```bash
# Connect as root
sudo mysql

# Connect as app user
mysql -u postguard -p postguard

# Dump database for backup
mysqldump -u postguard -p postguard > backup.sql

# Restore from backup
mysql -u postguard -p postguard < backup.sql

# Check query performance
EXPLAIN SELECT * FROM scans WHERE verdict = 'SCAM';

# Enable slow query log (edit /etc/mysql/mysql.conf.d/mysqld.cnf)
# slow_query_log = 1
# slow_query_log_file = /var/log/mysql/slow.log
# long_query_time = 2
```

## Common Gotcha
Watch for typos in GRANT statements. MySQL will silently create a new database if you grant privileges on a misspelled name (e.g., `posthuard.*` instead of `postguard.*`). Always verify with `SHOW DATABASES;` after.
