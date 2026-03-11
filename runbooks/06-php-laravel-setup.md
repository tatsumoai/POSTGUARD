# 06 - PHP and Laravel Setup

## Purpose
Install PHP with required extensions, Composer, and Laravel. Configure the application to connect to MySQL and the Anthropic API.

## Steps

### 1. Install PHP and Extensions
```bash
sudo apt install php php-cli php-mbstring php-xml php-curl php-mysql php-zip unzip -y
```

This installs the CLI version of PHP for running artisan commands.

### 2. Install PHP-FPM
```bash
sudo apt install php8.3-fpm -y
sudo systemctl status php8.3-fpm    # Should show "active (running)"
```

PHP-FPM (FastCGI Process Manager) is what nginx uses to serve PHP pages. It's a separate package from the CLI.

### 3. Install Composer
```bash
cd ~
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### 4. Verify Installations
```bash
php --version       # Should show 8.3.x
composer --version  # Should show 2.x
```

### 5. Create Laravel Project
```bash
cd ~
composer create-project laravel/laravel postguard
cd postguard
```

### 6. Generate Application Files
Use artisan to scaffold the model, migration, and controller:
```bash
php artisan make:model Scan -mc
```
This creates three files at once:
- `app/Models/Scan.php` (the model)
- `database/migrations/*_create_scans_table.php` (the migration)
- `app/Http/Controllers/ScanController.php` (the controller)

### 7. Configure Environment
Edit `.env` to set database credentials and API key:
```bash
# Use sed for reliable single-line replacements
sed -i 's/^.*DB_CONNECTION=.*/DB_CONNECTION=mysql/' .env
sed -i 's/^.*DB_DATABASE=.*/DB_DATABASE=postguard/' .env
sed -i 's/^.*DB_USERNAME=.*/DB_USERNAME=postguard/' .env
sed -i 's/^.*DB_PASSWORD=.*/DB_PASSWORD=YourPasswordHere/' .env

# Add API key (use single quotes to prevent shell interpretation)
echo 'ANTHROPIC_API_KEY=sk-ant-your-key-here' >> .env
```

### 8. Add Anthropic Config
In `config/services.php`, add inside the array:
```php
'anthropic' => [
    'api_key' => env('ANTHROPIC_API_KEY'),
],
```

### 9. Run Migrations and Clear Cache
```bash
php artisan migrate
php artisan config:clear
```

## Key Laravel Commands
```bash
php artisan serve --host=0.0.0.0 --port=8000  # Dev server (not for production)
php artisan migrate                              # Run migrations
php artisan migrate:rollback                     # Undo last migration
php artisan config:clear                         # Clear config cache
php artisan cache:clear                          # Clear app cache
php artisan view:clear                           # Clear compiled views
php artisan tinker                               # Interactive REPL
php artisan route:list                           # Show all routes
```

## Common Gotchas
- **"Could not find driver"** after setting DB_CONNECTION=mysql means `php-mysql` extension is missing. Install with `sudo apt install php-mysql`.
- **"Could not open input file: artisan"** means you're not in the project directory. Run `cd ~/postguard` first.
- **dotenv parse errors** usually mean a malformed line in `.env`. Check for missing quotes, leading spaces, or bare values without a KEY= prefix.
- **PHP-FPM vs PHP CLI** are separate. You need both. CLI runs artisan commands. FPM serves web requests through nginx.
