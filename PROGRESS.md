# PostGuard - Progress Tracker

## Overview

PostGuard is an AI-powered job posting analyzer that scores job listings for legitimacy, red flags, and scam indicators. Built on a manually configured Ubuntu server with nginx, MySQL, Laravel, and Claude AI integration.

**Live at:** https://postg.app

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

### Input Methods
- **Paste Text** - user copies and pastes job posting text directly
- **Paste Link** - user provides a URL, backend fetches and extracts text (falls back gracefully if site blocks access)

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
- Tab-switching input (Paste Text / Paste Link)
- Scan history with expandable cards
- Delete functionality with confirmation
- Word count on text input
- Loading state on form submission
- Auto-scroll to latest scan result
- Responsive design (mobile-friendly)
- Custom PostGuard logo in nav

### Data Storage
- All scans stored in MySQL `scans` table
- Fields: company, title, source, url, input_text, score, verdict, ai_content_score, salary, flags (JSON), positives (JSON), cautions (JSON), summary, timestamps
- History shows 20 most recent scans

---

## Files Modified/Created

### Server: /home/arthur/postguard/

| File | Purpose |
|------|---------|
| `app/Models/Scan.php` | Eloquent model with JSON casts for flags/positives/cautions |
| `app/Services/ClaudeService.php` | Anthropic API client, system prompt, URL fetcher |
| `app/Http/Controllers/ScanController.php` | Form handling, validation, Claude calls, CRUD |
| `routes/web.php` | Four routes: index, analyze, show, destroy |
| `config/services.php` | Added Anthropic API key config |
| `resources/views/layouts/app.blade.php` | Base layout with full CSS and nav |
| `resources/views/scans/index.blade.php` | Main page: input form + scan history |
| `database/migrations/*_create_scans_table.php` | Scans table schema |
| `.env` | Database credentials, API key |
| `public/POSTGUARDlogo.png` | Custom logo |

### Server Configuration

| File | Purpose |
|------|---------|
| `/etc/ssh/sshd_config` | SSH hardening (no root, no passwords) |
| `/etc/nginx/sites-available/postguard` | Nginx reverse proxy + SSL config |
| `/etc/letsencrypt/live/postg.app/` | SSL certificate (auto-renewing) |

---

## Key Lessons Learned

1. **Always create a non-root user first.** Root access should be a deliberate escalation (sudo), not the default.
2. **Disable root SSH login and password auth immediately.** These are the two most common attack vectors on public servers.
3. **Open SSH port before enabling the firewall.** Enabling ufw without allowing port 22 locks you out permanently.
4. **SSH is strict about file permissions.** `.ssh` directory must be 700, `authorized_keys` must be 600, and ownership must match the user. SSH silently fails if these are wrong.
5. **Know which machine you're on.** The prompt tells you: `arthur@ubuntu-...` = server. `PS C:\...` = local. Running server commands locally throws confusing errors.
6. **Keep SSH config changes: when upgrading packages**, choose "keep the local version" when apt asks about modified config files, or your hardening gets overwritten.
7. **Apache can sneak in as a dependency** and steal port 80 from nginx. Stop and disable it if that happens.
8. **PHP-FPM is separate from PHP CLI.** Installing `php` gives you the command-line tool for artisan. Installing `php-fpm` gives you the process manager nginx needs to serve web requests. You need both.
9. **Quote environment variables in bash.** Without single quotes, special characters in API keys get interpreted by the shell. `echo 'KEY=value' >> .env` not `echo KEY=value >> .env`.
10. **sed is powerful for inline file edits** but dangerous for multiline HTML. For complex edits, use PHP or nano instead.
11. **nano shortcuts:** Ctrl+O = save (letter O, not zero), Ctrl+X = exit, Ctrl+W = search.
12. **MySQL user permissions should follow least privilege.** Create a dedicated user that only has access to its own database, not root access to everything.
13. **DNS propagation is fast with DigitalOcean.** Nameserver changes propagated in under 5 minutes.
14. **Certbot automates SSL completely.** One command configures nginx, obtains the cert, and sets up auto-renewal.

---

## Architecture Decisions

1. **Laravel over Express/FastAPI** - chosen to demonstrate familiarity with the PHP ecosystem, directly relevant to the target role's tech stack.
2. **Server-rendered Blade over React SPA** - simpler deployment, no build step, full UI in a single file. Appropriate for the MVP scope.
3. **Claude Sonnet 4 over Opus** - faster response times and lower cost per scan. Sufficient quality for job posting analysis.
4. **Paste-first input over URL-first** - many job boards (LinkedIn, Indeed) block automated fetching. Paste is universally reliable. URL fetch is a bonus that works on sites that allow it.
5. **Single-file CSS in layout** - no build tooling needed. All styles in one place for easy iteration. Production would use Tailwind or a build pipeline.
6. **MySQL over SQLite** - matches the target role's database requirements and demonstrates proper user/permission management.

---

## Next Steps

- [ ] Add fail2ban for brute force protection
- [ ] Add more scan history features (search, filter by verdict)
- [ ] Add user authentication (scan history per user)
- [ ] Build Chrome extension for one-click scanning from job boards
- [ ] Add batch scanning (paste multiple listings)
- [ ] Add email alerts for new scam patterns detected
- [ ] Set up CI/CD pipeline for automated deployments
- [ ] Add rate limiting on the analyze endpoint

---

## Last Updated
2026-03-11 (initial build complete, live at https://postg.app)
