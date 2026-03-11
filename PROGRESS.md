# PostGuard - Progress Tracker

## Overview

PostGuard is an AI-powered job posting analyzer that scores job listings for legitimacy, red flags, and scam indicators. Built on a manually configured Ubuntu server with nginx, MySQL, Laravel, and Claude AI integration.

**Live at:** https://postg.app
**Repo:** https://github.com/tatsumoai/POSTGUARD

---

## Infrastructure Setup

### DigitalOcean Droplet (COMPLETE)

- **IP:** 142.93.113.189
- **OS:** Ubuntu 24.04.3 LTS
- **Plan:** Basic, Regular SSD, $6/month (1 vCPU, 1GB RAM, 25GB SSD)
- **Region:** NYC1
- **Domain:** postg.app (DNS via DigitalOcean, SSL via Let's Encrypt)

### Security Hardening (COMPLETE)

1. Created non-root user `arthur` with sudo access
2. Copied SSH key for key-based authentication
3. Disabled root SSH login (`PermitRootLogin no`)
4. Disabled password authentication (`PasswordAuthentication no`)
5. Configured UFW firewall: allow 22 (SSH), 80 (HTTP), 443 (HTTPS), deny all else
6. Default policy: deny incoming, allow outgoing
7. Rate limiting: Laravel throttle middleware (10 requests/min per IP on analyze endpoint)

### Services Installed (COMPLETE)

- **Nginx** - reverse proxy to PHP-FPM, SSL termination
- **MySQL 8.0** - database with dedicated `postguard` user, least-privilege access
- **PHP 8.3** + PHP-FPM - application runtime
- **Node.js 22** - available for future frontend tooling
- **Certbot** - automatic SSL certificate management
- **Apache2** - installed as dependency, stopped and disabled (nginx handles web serving)

### Application Stack (COMPLETE)

- **Laravel 12.54.0** - PHP framework
- **Composer 2.9.5** - PHP package manager
- **Claude Sonnet 4** - AI analysis via Anthropic API
- **Blade templates** - server-side rendered UI (no separate frontend build)

---

## Application Features (COMPLETE)

### Smart Input (v2, replaces tab-switching)
- Single textarea that auto-detects whether input is a URL or text
- Shows "Link detected" badge (blue) when a URL is pasted
- Shows word count when text is pasted
- No tab switching needed, just paste and go
- Backend routes to URL fetcher or direct text analysis based on detection

### AI Analysis (via Claude API)
- Legitimacy score (0-100) with verdict classification (LEGIT/CAUTION/SUSPICIOUS/SCAM)
- Red flag detection with specific, concrete descriptions
- Positive signal detection
- Caution notes for things worth noting but not red flags
- AI content detection score (0-100, estimating if posting was AI-generated)
- Plain-English summary written conversationally

### UI Components
- Score gauge (SVG circle with color-coded progress arc)
- Verdict badge (color-coded pill: green/yellow/orange/red)
- AI detection bar (blue-to-green gradient, midpoint = AI score)
- Accordion sections for flags, positives, cautions, and analysis
- Smart input with auto-detection (URL vs text)
- Scan history with expandable cards
- Delete functionality with confirmation
- Word count on text input
- Loading state on form submission
- Auto-scroll to latest scan result
- Responsive design (mobile-friendly)
- Custom PostGuard logo with favicon
- GitHub source link in nav
- Footer with attribution

### Data Storage
- All scans stored in MySQL `scans` table
- Fields: company, title, source, url, input_text, score, verdict, ai_content_score, salary, flags (JSON), positives (JSON), cautions (JSON), summary, timestamps
- History shows 20 most recent scans

### Security
- Rate limiting: 10 scans per minute per IP via Laravel throttle middleware
- CSRF protection on all forms
- Input validation (minimum 50 characters for text, valid URL format for links)

---

## Build Log

### Session 1: Infrastructure + App (March 10-11, 2026)

**Duration:** ~2 hours active build time

**Infrastructure built:**
1. Provisioned DigitalOcean droplet (Ubuntu 24.04, NYC1)
2. Created non-root user with SSH key access
3. Hardened SSH (disabled root login, password auth)
4. Configured UFW firewall (ports 22, 80, 443 only)
5. Installed and configured nginx as reverse proxy
6. Installed MySQL, created database with dedicated user
7. Installed PHP 8.3 + PHP-FPM + Composer
8. Scaffolded Laravel 12 project
9. Configured DNS via DigitalOcean (postg.app)
10. Installed SSL via Let's Encrypt/Certbot

**Application built:**
1. Scan model with migration (MySQL schema for job analysis results)
2. ClaudeService (Anthropic API client with prompt engineering and URL fetcher)
3. ScanController (form handling, validation, Claude calls, CRUD operations)
4. Blade layout with full dark-theme CSS (score gauges, verdict badges, AI bars, accordions)
5. Main view with scan form and history display

**UI polish (update-ui.sh):**
1. Replaced tab-switching input with single smart input (auto-detects URL vs text)
2. Added custom PostGuard logo in nav
3. Added favicon.ico
4. Added GitHub source link in nav
5. Added footer with attribution
6. Brightened all muted/faint text for better readability
7. Added rate limiting middleware to analyze route

---

## Files Modified/Created

### Server: /home/arthur/postguard/

| File | Purpose |
|------|---------|
| `app/Models/Scan.php` | Eloquent model with JSON casts for flags/positives/cautions |
| `app/Services/ClaudeService.php` | Anthropic API client, system prompt, URL fetcher |
| `app/Http/Controllers/ScanController.php` | Form handling, validation, Claude calls, CRUD |
| `routes/web.php` | Four routes: index, analyze (throttled), show, destroy |
| `config/services.php` | Added Anthropic API key config |
| `resources/views/layouts/app.blade.php` | Base layout with full CSS, nav with logo + GitHub link, footer |
| `resources/views/scans/index.blade.php` | Main page: smart input + scan history cards |
| `database/migrations/*_create_scans_table.php` | Scans table schema |
| `public/POSTGUARDlogo.png` | Custom logo |
| `public/favicon.ico` | Browser tab icon |
| `.env` | Database credentials, API key |

### Server Configuration

| File | Purpose |
|------|---------|
| `/etc/ssh/sshd_config` | SSH hardening (no root, no passwords) |
| `/etc/nginx/sites-available/postguard` | Nginx reverse proxy + SSL config |
| `/etc/letsencrypt/live/postg.app/` | SSL certificate (auto-renewing) |

### Repo Files

| File | Purpose |
|------|---------|
| `README.md` | Full project documentation |
| `PROGRESS.md` | This file, detailed build log |
| `setup-postguard.sh` | Initial setup script (migration, model, controller, service, views) |
| `update-ui.sh` | UI update script (smart input, brighter text, favicon, GitHub link, footer) |
| `runbooks/` | Seven infrastructure documentation files |
| `POSTGUARDlogo.png` | Logo source file |
| `favicon.ico` | Favicon source file |

---

## Key Lessons Learned

1. **Always create a non-root user first.** Root access should be a deliberate escalation (sudo), not the default.
2. **Disable root SSH login and password auth immediately.** These are the two most common attack vectors on public servers.
3. **Open SSH port before enabling the firewall.** Enabling ufw without allowing port 22 locks you out permanently.
4. **SSH is strict about file permissions.** `.ssh` directory must be 700, `authorized_keys` must be 600, and ownership must match the user. SSH silently fails if these are wrong.
5. **Know which machine you're on.** The prompt tells you: `arthur@ubuntu-...` = server. `PS C:\...` = local. Running server commands locally throws confusing errors. SCP always runs from local.
6. **Keep SSH config changes when upgrading packages.** Choose "keep the local version" when apt asks about modified config files, or your hardening gets overwritten.
7. **Apache can sneak in as a dependency** and steal port 80 from nginx. Stop and disable it if that happens.
8. **PHP-FPM is separate from PHP CLI.** Installing `php` gives you the command-line tool for artisan. Installing `php-fpm` gives you the process manager nginx needs to serve web requests. You need both.
9. **Quote environment variables in bash.** Without single quotes, special characters in API keys get interpreted by the shell. `echo 'KEY=value' >> .env` not `echo KEY=value >> .env`.
10. **sed is powerful for inline file edits** but dangerous for multiline HTML. For complex edits, use PHP or nano instead.
11. **nano shortcuts:** Ctrl+O = save (letter O, not zero), Ctrl+X = exit, Ctrl+W = search.
12. **MySQL user permissions should follow least privilege.** Create a dedicated user that only has access to its own database, not root access to everything.
13. **DNS propagation is fast with DigitalOcean.** Nameserver changes propagated in under 5 minutes.
14. **Certbot automates SSL completely.** One command configures nginx, obtains the cert, and sets up auto-renewal.
15. **nginx permissions require directory traversal.** `www-data` needs `chmod o+x` on the user's home directory to reach the Laravel public folder.
16. **Watch for typos in MySQL GRANT statements.** MySQL silently creates a new database if you grant privileges on a misspelled name.

---

## Architecture Decisions

1. **Laravel over Express/FastAPI** - chosen to demonstrate familiarity with the PHP ecosystem, directly relevant to the target role's tech stack.
2. **Server-rendered Blade over React SPA** - simpler deployment, no build step, full UI in a single file. Appropriate for the MVP scope.
3. **Claude Sonnet 4 over Opus** - faster response times and lower cost per scan. Sufficient quality for job posting analysis.
4. **Smart input over tab-switching** - single input box that auto-detects URL vs text is better UX. Users don't have to think about which tab to use, just paste and go.
5. **Single-file CSS in layout** - no build tooling needed. All styles in one place for easy iteration. Production would use Tailwind or a build pipeline.
6. **MySQL over SQLite** - matches the target role's database requirements and demonstrates proper user/permission management.
7. **IP-based rate limiting for MVP** - simple throttle middleware protects the API budget without requiring authentication. Future: freemium gate (3 free scans/day, email for 10/day).

---

## Next Steps

- [x] ~~Add rate limiting on the analyze endpoint~~
- [ ] Add fail2ban for brute force protection
- [ ] Add freemium scan gate (3 free/day by IP, 10/day with email)
- [ ] Add more scan history features (search, filter by verdict)
- [ ] Add user authentication (scan history per user)
- [ ] Build Chrome extension for one-click scanning from job boards
- [ ] Add batch scanning (paste multiple listings)
- [ ] Add email alerts for new scam patterns detected
- [ ] Set up CI/CD pipeline for automated deployments
- [ ] Add to tatsumosoft.com portfolio

---

## Last Updated
2026-03-11 (UI update: smart input, brighter text, favicon, GitHub link, footer, rate limiting)
