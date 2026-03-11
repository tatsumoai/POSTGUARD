# PostGuard

AI-powered job posting legitimacy analyzer. Paste a job listing (or URL), get an instant analysis with a legitimacy score, red flag detection, AI-generated content assessment, and actionable insights.

**Live at:** [https://postg.app](https://postg.app)

## What It Does

PostGuard takes a job posting as input and runs it through Claude AI to produce:

- **Legitimacy Score (0-100)** with color-coded verdict (LEGIT / CAUTION / SUSPICIOUS / SCAM)
- **Red Flag Detection** identifying specific concerns like PayPal-only payment, vague compensation, or missing company details
- **Positive Signal Detection** highlighting transparent salary ranges, verifiable leadership, and specific technical requirements
- **AI Content Detection** estimating how likely the posting was written by AI (blue-to-green gradient bar)
- **Plain-English Analysis** summarizing the findings like a knowledgeable friend, not a robot

All results are stored in MySQL and displayed in a scan history dashboard.

## Architecture

```
Browser (user pastes job posting or URL)
    |
    v
Nginx (reverse proxy + SSL via Let's Encrypt)
    |
    v
Laravel 12 (PHP 8.3, routes, controllers, Blade views)
    |
    +--- Claude Sonnet 4 API (job posting analysis)
    +--- MySQL 8.0 (scan history storage)
    |
    v
Results rendered in dark-themed UI with score gauges,
verdict badges, AI detection bars, and accordion sections
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Server | Ubuntu 24.04 LTS on DigitalOcean |
| Web Server | Nginx (reverse proxy to PHP-FPM) |
| SSL | Let's Encrypt via Certbot (auto-renewing) |
| Framework | Laravel 12.54.0 |
| Language | PHP 8.3.6 |
| Database | MySQL 8.0 |
| AI | Claude Sonnet 4 (Anthropic API) |
| DNS | DigitalOcean DNS |
| Domain | postg.app |

## Infrastructure

The server was configured from scratch with security hardening:

- Non-root user with sudo access (no root SSH login)
- SSH key-only authentication (password auth disabled)
- UFW firewall (only ports 22, 80, 443 open)
- SSL/TLS via Let's Encrypt with automatic renewal
- PHP-FPM for process management
- MySQL with dedicated app user and least-privilege permissions
- Rate limiting via Laravel throttle middleware (10 requests/min per IP)

See the [runbooks/](runbooks/) directory for detailed documentation of every infrastructure step.

## Project Structure

```
Server: /home/arthur/postguard/
|-- app/
|   |-- Http/Controllers/ScanController.php   # handles form submission, Claude API calls, CRUD
|   |-- Models/Scan.php                        # Eloquent model with JSON casts for flags/positives
|   |-- Services/ClaudeService.php             # Anthropic API client, prompt engineering, URL fetcher
|-- database/migrations/                       # scans table schema
|-- resources/views/
|   |-- layouts/app.blade.php                  # base layout with full CSS (dark theme, components)
|   |-- scans/index.blade.php                  # main page: input form + scan history cards
|-- routes/web.php                             # GET /, POST /analyze, GET /scan/{id}, DELETE /scan/{id}
|-- public/
|   |-- POSTGUARDlogo.png                      # logo used in nav and as fallback favicon
|   |-- favicon.ico                            # browser tab icon
|-- .env                                       # environment config (DB credentials, API key)
```

## Key Features

- **Smart Input Detection** - single input box auto-detects whether you pasted a URL or text. Shows "Link detected" for URLs, word count for text. No tab switching needed.
- **URL Fetching** - if a URL is pasted, the backend fetches the page, strips HTML to readable text, and sends it to Claude. Falls back gracefully if the site blocks access.
- **Score Gauge** - SVG circle with color-coded progress arc (green 80+, yellow 60-79, red below 60).
- **AI Detection Bar** - blue-to-green gradient where the midpoint shifts based on AI score percentage.
- **Accordion Sections** - expandable Red Flags, Positive Signals, Cautions, and Analysis sections.
- **Rate Limiting** - Laravel throttle middleware limits to 10 scans per minute per IP.
- **Custom Logo** - PostGuard shield logo with castle battlements and embedded P.

## Key Files

- **ClaudeService.php** - The AI integration. Contains the system prompt with scoring guidelines, red flag definitions, and anti-AI-language rules. Also handles URL fetching with HTML stripping for the link input feature.
- **ScanController.php** - Handles form validation (smart detection of text vs URL input), calls ClaudeService, stores results in MySQL, and manages the scan history.
- **app.blade.php** - Complete UI in a single Blade layout. Dark theme with CSS variables, score gauge SVGs, gradient AI detection bar, accordion components, GitHub source link, footer, and responsive design.
- **index.blade.php** - Main view with smart input (auto-detects URL vs text), scan card rendering with expandable details, and JavaScript for interactivity.

## Runbooks

Infrastructure documentation for every setup step:

- [01 - Initial Server Setup](runbooks/01-initial-server-setup.md)
- [02 - SSH Hardening](runbooks/02-ssh-hardening.md)
- [03 - Firewall Configuration](runbooks/03-firewall-config.md)
- [04 - Nginx Setup](runbooks/04-nginx-setup.md)
- [05 - MySQL Setup](runbooks/05-mysql-setup.md)
- [06 - PHP and Laravel Setup](runbooks/06-php-laravel-setup.md)
- [07 - DNS and SSL](runbooks/07-dns-ssl.md)

## Local Development

The app runs on a DigitalOcean droplet. To deploy changes:

```bash
# SSH into the server
ssh arthur@142.93.113.189

# Navigate to the project
cd ~/postguard

# Pull latest changes (if using git on server)
git pull

# Clear caches after changes
php artisan config:clear
php artisan cache:clear
php artisan view:clear

# Restart services if needed
sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm
```

## Environment Variables

```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=postguard
DB_USERNAME=postguard
DB_PASSWORD=<your-db-password>
ANTHROPIC_API_KEY=<your-api-key>
```

## License

Private project. All rights reserved.
