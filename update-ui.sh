#!/bin/bash
# PostGuard Update Script - UI improvements
# Run from ~/postguard on the server
set -e
echo "=== PostGuard UI Update ==="

# ── 1. Generate favicon from logo ─────────────────────────────────────
echo "[1/4] Setting up favicon..."
# The PNG logo is already in public/, just reference it as favicon
echo "  -> Using POSTGUARDlogo.png as favicon"

# ── 2. Update layout: favicon, repo link, brighter text ───────────────
echo "[2/4] Updating layout..."

cat > resources/views/layouts/app.blade.php << 'LAYOUT'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PostGuard - Job Posting Analyzer</title>
    <link rel="icon" type="image/png" href="/POSTGUARDlogo.png">
    <link rel="apple-touch-icon" href="/POSTGUARDlogo.png">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        ::selection { background: rgba(59,130,246,0.3); }

        :root {
            --bg: #08090d;
            --surface: rgba(255,255,255,0.02);
            --border: rgba(255,255,255,0.07);
            --border-hover: rgba(255,255,255,0.12);
            --text: rgba(255,255,255,0.92);
            --text-muted: rgba(255,255,255,0.65);
            --text-faint: rgba(255,255,255,0.4);
            --blue: #3b82f6;
            --green: #22c55e;
            --yellow: #eab308;
            --red: #ef4444;
            --orange: #f97316;
            --font-body: 'DM Sans', -apple-system, sans-serif;
            --font-mono: 'Space Mono', monospace;
        }

        body {
            background: var(--bg);
            color: var(--text);
            font-family: var(--font-body);
            min-height: 100vh;
            -webkit-font-smoothing: antialiased;
        }

        .nav { display: flex; align-items: center; justify-content: space-between; padding: 16px 32px; border-bottom: 1px solid rgba(255,255,255,0.05); }
        .nav-left { display: flex; align-items: center; gap: 12px; }
        .nav-brand { display: flex; align-items: center; gap: 12px; text-decoration: none; color: var(--text); }
        .nav-logo { width: 36px; height: 36px; border-radius: 10px; display: flex; align-items: center; justify-content: center; }
        .nav-logo img { width: 36px; height: 36px; border-radius: 10px; }
        .nav-title { font-size: 24px; font-weight: 700; letter-spacing: -0.02em; }
        .nav-badge { font-size: 10px; padding: 3px 8px; border-radius: 6px; background: rgba(59,130,246,0.1); border: 1px solid rgba(59,130,246,0.2); color: #93c5fd; font-family: var(--font-mono); font-weight: 700; }
        .nav-right { display: flex; align-items: center; gap: 16px; }
        .nav-stats { font-size: 12px; color: var(--text-faint); font-family: var(--font-mono); }
        .nav-link { font-size: 12px; color: var(--text-faint); font-family: var(--font-mono); text-decoration: none; padding: 4px 10px; border-radius: 6px; border: 1px solid rgba(255,255,255,0.1); transition: all 0.2s; }
        .nav-link:hover { color: var(--text-muted); border-color: rgba(255,255,255,0.2); background: rgba(255,255,255,0.04); }
        .nav-link svg { display: inline-block; vertical-align: middle; margin-right: 4px; }
        .container { max-width: 780px; margin: 0 auto; padding: 32px 24px; }
        .page-title { font-size: 28px; font-weight: 700; letter-spacing: -0.02em; margin-bottom: 6px; }
        .page-subtitle { font-size: 14px; color: var(--text-muted); margin-bottom: 20px; }
        .input-card { border-radius: 14px; background: var(--surface); border: 1px solid var(--border); overflow: hidden; margin-bottom: 32px; }
        textarea { width: 100%; padding: 16px 20px; background: transparent; border: none; color: var(--text); font-size: 14px; line-height: 1.6; font-family: var(--font-body); resize: vertical; outline: none; min-height: 140px; }
        textarea::placeholder { color: rgba(255,255,255,0.25); }
        .input-footer { display: flex; align-items: center; justify-content: space-between; padding: 12px 20px; border-top: 1px solid rgba(255,255,255,0.05); }
        .input-meta { display: flex; align-items: center; gap: 12px; }
        .word-count { font-size: 11px; color: var(--text-faint); font-family: var(--font-mono); }
        .input-mode { font-size: 11px; color: var(--text-faint); font-family: var(--font-mono); padding: 3px 8px; border-radius: 4px; background: rgba(255,255,255,0.04); }
        .input-mode.url-mode { color: var(--blue); background: rgba(59,130,246,0.1); }
        .btn-analyze { padding: 10px 28px; border-radius: 10px; border: none; background: linear-gradient(135deg, var(--blue), var(--green)); color: #fff; font-size: 13px; font-weight: 700; font-family: var(--font-body); cursor: pointer; transition: all 0.2s; letter-spacing: 0.01em; }
        .btn-analyze:hover { opacity: 0.9; transform: translateY(-1px); }
        .btn-analyze:disabled { background: rgba(255,255,255,0.06); color: var(--text-faint); cursor: not-allowed; transform: none; }
        .error-bar { padding: 14px 20px; background: rgba(239,68,68,0.1); border: 1px solid rgba(239,68,68,0.2); border-radius: 10px; color: #fca5a5; font-size: 13px; margin-bottom: 20px; }
        .status-bar { padding: 14px 20px; background: rgba(34,197,94,0.1); border: 1px solid rgba(34,197,94,0.2); border-radius: 10px; color: #86efac; font-size: 13px; margin-bottom: 20px; }
        .section-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
        .section-title { font-size: 16px; font-weight: 700; color: rgba(255,255,255,0.8); }
        .section-count { font-size: 11px; color: var(--text-faint); font-family: var(--font-mono); }
        .scan-card { background: var(--surface); border: 1px solid var(--border); border-radius: 16px; overflow: hidden; transition: border-color 0.2s; margin-bottom: 12px; }
        .scan-card:hover { border-color: var(--border-hover); }
        .scan-card-header { padding: 20px 24px; display: flex; align-items: center; gap: 20px; cursor: pointer; }
        .score-gauge { position: relative; width: 80px; height: 80px; flex-shrink: 0; }
        .score-gauge svg { width: 80px; height: 80px; }
        .score-gauge-label { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; }
        .score-gauge-number { font-size: 26px; font-weight: 800; font-family: var(--font-mono); line-height: 1; }
        .score-gauge-sub { font-size: 7px; color: var(--text-faint); font-family: var(--font-mono); text-transform: uppercase; letter-spacing: 0.1em; margin-top: 2px; }
        .score-green .score-gauge-number { color: var(--green); }
        .score-yellow .score-gauge-number { color: var(--yellow); }
        .score-red .score-gauge-number { color: var(--red); }
        .card-info { flex: 1; min-width: 0; }
        .card-top { display: flex; align-items: center; gap: 10px; margin-bottom: 4px; flex-wrap: wrap; }
        .card-company { font-size: 16px; font-weight: 700; }
        .card-title { font-size: 13px; color: var(--text-muted); margin-bottom: 4px; }
        .card-meta { display: flex; align-items: center; gap: 12px; font-size: 11px; font-family: var(--font-mono); color: var(--text-faint); }
        .card-meta-sep { opacity: 0.3; }
        .card-chevron { color: rgba(255,255,255,0.3); font-size: 12px; transition: transform 0.2s; flex-shrink: 0; }
        .scan-card.expanded .card-chevron { transform: rotate(180deg); }
        .verdict-badge { display: inline-block; padding: 4px 14px; border-radius: 20px; font-size: 11px; font-weight: 700; font-family: var(--font-mono); letter-spacing: 0.08em; }
        .verdict-LEGIT { background: rgba(34,197,94,0.12); border: 1px solid rgba(34,197,94,0.3); color: var(--green); box-shadow: 0 0 12px rgba(34,197,94,0.2); }
        .verdict-CAUTION { background: rgba(234,179,8,0.12); border: 1px solid rgba(234,179,8,0.3); color: var(--yellow); box-shadow: 0 0 12px rgba(234,179,8,0.2); }
        .verdict-SUSPICIOUS { background: rgba(249,115,22,0.12); border: 1px solid rgba(249,115,22,0.3); color: var(--orange); box-shadow: 0 0 12px rgba(249,115,22,0.2); }
        .verdict-SCAM { background: rgba(239,68,68,0.12); border: 1px solid rgba(239,68,68,0.3); color: var(--red); box-shadow: 0 0 12px rgba(239,68,68,0.2); }
        .verdict-UNKNOWN { background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.15); color: var(--text-muted); }
        .card-body { display: none; padding: 0 24px 24px; flex-direction: column; gap: 16px; border-top: 1px solid rgba(255,255,255,0.06); padding-top: 20px; }
        .scan-card.expanded .card-body { display: flex; }
        .ai-section-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-faint); font-family: var(--font-mono); margin-bottom: 10px; }
        .ai-bar-labels { display: flex; justify-content: space-between; margin-bottom: 6px; font-size: 11px; font-family: var(--font-mono); }
        .ai-bar-ai { color: var(--blue); }
        .ai-bar-human { color: var(--green); }
        .ai-bar { height: 8px; border-radius: 4px; box-shadow: inset 0 1px 2px rgba(0,0,0,0.3); }
        .ai-bar-note { font-size: 11px; color: var(--text-muted); margin-top: 4px; }
        .accordion { border-radius: 10px; background: var(--surface); border: 1px solid rgba(255,255,255,0.06); overflow: hidden; }
        .accordion-header { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; background: none; border: none; color: rgba(255,255,255,0.8); cursor: pointer; font-family: var(--font-body); font-size: 13px; font-weight: 600; }
        .accordion-chevron { font-size: 10px; opacity: 0.5; transition: transform 0.2s; }
        .accordion.open .accordion-chevron { transform: rotate(180deg); }
        .accordion-body { max-height: 0; overflow: hidden; transition: max-height 0.3s ease; }
        .accordion.open .accordion-body { max-height: 600px; }
        .accordion-content { padding: 0 16px 14px; }
        .chip { display: flex; align-items: flex-start; gap: 8px; padding: 8px 12px; border-radius: 8px; font-size: 12px; line-height: 1.4; margin-bottom: 6px; }
        .chip-icon { flex-shrink: 0; font-size: 10px; margin-top: 2px; }
        .chip-flag { background: rgba(239,68,68,0.08); border: 1px solid rgba(239,68,68,0.15); color: #fca5a5; }
        .chip-flag .chip-icon { color: var(--red); }
        .chip-positive { background: rgba(34,197,94,0.08); border: 1px solid rgba(34,197,94,0.15); color: #86efac; }
        .chip-positive .chip-icon { color: var(--green); }
        .chip-caution { background: rgba(234,179,8,0.08); border: 1px solid rgba(234,179,8,0.15); color: #fde68a; }
        .chip-caution .chip-icon { color: var(--yellow); }
        .summary-text { font-size: 13px; line-height: 1.7; color: rgba(255,255,255,0.75); }
        .card-actions { display: flex; justify-content: flex-end; gap: 8px; padding-top: 12px; border-top: 1px solid rgba(255,255,255,0.04); }
        .btn-sm { padding: 6px 14px; border-radius: 8px; font-size: 11px; font-family: var(--font-mono); cursor: pointer; transition: all 0.2s; border: 1px solid rgba(255,255,255,0.1); background: rgba(255,255,255,0.04); color: var(--text-muted); text-decoration: none; }
        .btn-sm:hover { background: rgba(255,255,255,0.08); }
        .btn-danger { border-color: rgba(239,68,68,0.2); color: #fca5a5; }
        .btn-danger:hover { background: rgba(239,68,68,0.1); }
        .empty-state { text-align: center; padding: 60px 20px; color: var(--text-muted); font-size: 14px; }
        .empty-icon { font-size: 40px; margin-bottom: 12px; opacity: 0.3; }
        .footer { text-align: center; padding: 24px; border-top: 1px solid rgba(255,255,255,0.04); margin-top: 40px; }
        .footer-text { font-size: 11px; color: var(--text-faint); font-family: var(--font-mono); }
        .footer-text a { color: var(--text-muted); text-decoration: none; }
        .footer-text a:hover { color: var(--text); }
        @media (max-width: 640px) { .nav { padding: 12px 16px; flex-wrap: wrap; gap: 8px; } .container { padding: 20px 16px; } .page-title { font-size: 22px; } .scan-card-header { padding: 16px; gap: 14px; } .card-body { padding: 0 16px 16px; padding-top: 16px; } .card-meta { flex-wrap: wrap; gap: 6px; } .nav-right { gap: 8px; } }
    </style>
</head>
<body>
    <nav class="nav">
        <a href="/" class="nav-brand">
            <div class="nav-logo"><img src="/POSTGUARDlogo.png" alt="PostGuard" width="36" height="36" style="border-radius:10px;"></div>
            <span class="nav-title">PostGuard</span>
            <span class="nav-badge">BETA</span>
        </a>
        <div class="nav-right">
            <span class="nav-stats">{{ \App\Models\Scan::whereDate('created_at', today())->count() }} scans today</span>
            <a href="https://github.com/tatsumoai/postguard" target="_blank" class="nav-link">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
                Source
            </a>
        </div>
    </nav>

    <div class="container">
        @yield('content')
    </div>

    <footer class="footer">
        <p class="footer-text">Built by <a href="https://github.com/tatsumoai" target="_blank">Arthur Fogle</a> &middot; Powered by Claude AI</p>
    </footer>

    @yield('scripts')
</body>
</html>
LAYOUT

echo "  -> resources/views/layouts/app.blade.php"

# ── 3. Update index view: single smart input ──────────────────────────
echo "[3/4] Updating index view with smart input..."

cat > resources/views/scans/index.blade.php << 'VIEW'
@extends('layouts.app')

@section('content')
    <h1 class="page-title">Scan a job posting</h1>
    <p class="page-subtitle">Paste a job posting or a link below. PostGuard will analyze it for legitimacy, red flags, and AI-generated content.</p>

    @if ($errors->any())
        <div class="error-bar">
            @foreach ($errors->all() as $error)
                {{ $error }}<br>
            @endforeach
        </div>
    @endif

    @if (session('status'))
        <div class="status-bar">{{ session('status') }}</div>
    @endif

    <div class="input-card">
        <form method="POST" action="{{ route('scans.analyze') }}" id="scan-form">
            @csrf
            <input type="hidden" name="input_text" id="hidden-text" value="">
            <input type="hidden" name="url" id="hidden-url" value="">
            <textarea id="smart-input" placeholder="Paste a job posting or a URL here...">{{ old('input_text') ?? old('url') }}</textarea>
            <div class="input-footer">
                <div class="input-meta">
                    <span class="word-count" id="word-count"></span>
                    <span class="input-mode" id="input-mode"></span>
                </div>
                <button type="submit" class="btn-analyze" id="btn-submit">Analyze Posting</button>
            </div>
        </form>
    </div>

    @if ($scans->count() > 0)
        <div class="section-header">
            <h2 class="section-title">Recent Scans</h2>
            <span class="section-count">{{ $scans->count() }} results</span>
        </div>

        @foreach ($scans as $scan)
            @php
                $scoreClass = $scan->score >= 80 ? 'score-green' : ($scan->score >= 60 ? 'score-yellow' : 'score-red');
                $scoreColor = $scan->score >= 80 ? '#22c55e' : ($scan->score >= 60 ? '#eab308' : '#ef4444');
                $scoreGlow = $scan->score >= 80 ? 'rgba(34,197,94,0.3)' : ($scan->score >= 60 ? 'rgba(234,179,8,0.3)' : 'rgba(239,68,68,0.3)');
                $radius = 32;
                $circumference = 2 * pi() * $radius;
                $progress = ($scan->score / 100) * $circumference;
                $isLatest = session('latest_scan_id') == $scan->id;
            @endphp

            <div class="scan-card {{ $isLatest ? 'expanded' : '' }}" id="scan-{{ $scan->id }}">
                <div class="scan-card-header" onclick="toggleCard({{ $scan->id }})">
                    <div class="score-gauge {{ $scoreClass }}">
                        <svg viewBox="0 0 80 80">
                            <circle cx="40" cy="40" r="{{ $radius }}" fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="6"/>
                            <circle cx="40" cy="40" r="{{ $radius }}" fill="none" stroke="{{ $scoreColor }}" stroke-width="6"
                                stroke-dasharray="{{ $circumference }}" stroke-dashoffset="{{ $circumference - $progress }}"
                                stroke-linecap="round" transform="rotate(-90 40 40)"
                                style="filter: drop-shadow(0 0 6px {{ $scoreGlow }}); transition: stroke-dashoffset 1s ease-out;"/>
                        </svg>
                        <div class="score-gauge-label">
                            <span class="score-gauge-number">{{ $scan->score }}</span>
                            <span class="score-gauge-sub">of 100</span>
                        </div>
                    </div>

                    <div class="card-info">
                        <div class="card-top">
                            <span class="card-company">{{ $scan->company }}</span>
                            <span class="verdict-badge verdict-{{ $scan->verdict }}">{{ $scan->verdict }}</span>
                        </div>
                        <div class="card-title">{{ $scan->title }}</div>
                        <div class="card-meta">
                            @if ($scan->salary)
                                <span>{{ $scan->salary }}</span>
                                <span class="card-meta-sep">|</span>
                            @endif
                            <span>{{ $scan->source }}</span>
                            <span class="card-meta-sep">|</span>
                            <span>{{ $scan->scanned_at->format('M j, Y g:ia') }}</span>
                        </div>
                    </div>

                    <span class="card-chevron">&#9660;</span>
                </div>

                <div class="card-body">
                    @if ($scan->ai_content_score !== null)
                        <div>
                            <div class="ai-section-label">AI Content Detection</div>
                            <div class="ai-bar-labels">
                                <span class="ai-bar-ai">AI {{ $scan->ai_content_score }}%</span>
                                <span class="ai-bar-human">Human {{ 100 - $scan->ai_content_score }}%</span>
                            </div>
                            <div class="ai-bar" style="background: linear-gradient(to right, #3b82f6 0%, #3b82f6 {{ max(0, $scan->ai_content_score - 5) }}%, #22c55e {{ min(100, $scan->ai_content_score + 5) }}%, #22c55e 100%);"></div>
                            <div class="ai-bar-note">
                                @if ($scan->ai_content_score >= 70)
                                    Posting likely written with AI assistance
                                @elseif ($scan->ai_content_score >= 40)
                                    Mix of human and AI-generated content
                                @else
                                    Posting appears primarily human-written
                                @endif
                            </div>
                        </div>
                    @endif

                    @if (!empty($scan->flags))
                        <div class="accordion open">
                            <button class="accordion-header" onclick="toggleAccordion(this)">
                                Red Flags ({{ count($scan->flags) }})
                                <span class="accordion-chevron">&#9660;</span>
                            </button>
                            <div class="accordion-body">
                                <div class="accordion-content">
                                    @foreach ($scan->flags as $flag)
                                        <div class="chip chip-flag">
                                            <span class="chip-icon">&#9888;</span>
                                            <span>{{ $flag }}</span>
                                        </div>
                                    @endforeach
                                </div>
                            </div>
                        </div>
                    @endif

                    @if (!empty($scan->positives))
                        <div class="accordion {{ empty($scan->flags) ? 'open' : '' }}">
                            <button class="accordion-header" onclick="toggleAccordion(this)">
                                Positive Signals ({{ count($scan->positives) }})
                                <span class="accordion-chevron">&#9660;</span>
                            </button>
                            <div class="accordion-body">
                                <div class="accordion-content">
                                    @foreach ($scan->positives as $positive)
                                        <div class="chip chip-positive">
                                            <span class="chip-icon">&#10003;</span>
                                            <span>{{ $positive }}</span>
                                        </div>
                                    @endforeach
                                </div>
                            </div>
                        </div>
                    @endif

                    @if (!empty($scan->cautions))
                        <div class="accordion">
                            <button class="accordion-header" onclick="toggleAccordion(this)">
                                Cautions ({{ count($scan->cautions) }})
                                <span class="accordion-chevron">&#9660;</span>
                            </button>
                            <div class="accordion-body">
                                <div class="accordion-content">
                                    @foreach ($scan->cautions as $caution)
                                        <div class="chip chip-caution">
                                            <span class="chip-icon">&#9679;</span>
                                            <span>{{ $caution }}</span>
                                        </div>
                                    @endforeach
                                </div>
                            </div>
                        </div>
                    @endif

                    @if ($scan->summary)
                        <div class="accordion open">
                            <button class="accordion-header" onclick="toggleAccordion(this)">
                                Analysis
                                <span class="accordion-chevron">&#9660;</span>
                            </button>
                            <div class="accordion-body">
                                <div class="accordion-content">
                                    <p class="summary-text">{{ $scan->summary }}</p>
                                </div>
                            </div>
                        </div>
                    @endif

                    <div class="card-actions">
                        @if ($scan->url)
                            <a href="{{ $scan->url }}" target="_blank" class="btn-sm">View Original</a>
                        @endif
                        <form method="POST" action="{{ route('scans.destroy', $scan) }}" style="display:inline;" onsubmit="return confirm('Delete this scan?')">
                            @csrf
                            @method('DELETE')
                            <button type="submit" class="btn-sm btn-danger">Delete</button>
                        </form>
                    </div>
                </div>
            </div>
        @endforeach
    @else
        <div class="empty-state">
            <div class="empty-icon">&#128737;</div>
            <p>No scans yet. Paste a job posting above to get started.</p>
        </div>
    @endif
@endsection

@section('scripts')
<script>
    const smartInput = document.getElementById('smart-input');
    const hiddenText = document.getElementById('hidden-text');
    const hiddenUrl = document.getElementById('hidden-url');
    const wordCount = document.getElementById('word-count');
    const inputMode = document.getElementById('input-mode');

    function isUrl(text) {
        const trimmed = text.trim();
        if (trimmed.includes('\n')) return false;
        if (trimmed.includes(' ') && trimmed.length > 100) return false;
        try {
            const url = new URL(trimmed);
            return url.protocol === 'http:' || url.protocol === 'https:';
        } catch {
            return /^(https?:\/\/|www\.)[^\s]+\.[^\s]{2,}/.test(trimmed);
        }
    }

    function updateInputState() {
        const val = smartInput.value;
        const trimmed = val.trim();

        if (!trimmed) {
            wordCount.textContent = '';
            inputMode.textContent = '';
            inputMode.className = 'input-mode';
            return;
        }

        if (isUrl(trimmed)) {
            wordCount.textContent = '';
            inputMode.textContent = 'Link detected';
            inputMode.className = 'input-mode url-mode';
        } else {
            const words = trimmed.split(/\s+/).filter(Boolean).length;
            wordCount.textContent = words + ' words';
            inputMode.textContent = 'Text';
            inputMode.className = 'input-mode';
        }
    }

    smartInput.addEventListener('input', updateInputState);
    updateInputState();

    document.getElementById('scan-form').addEventListener('submit', function(e) {
        const val = smartInput.value.trim();

        if (!val) {
            e.preventDefault();
            return;
        }

        if (isUrl(val)) {
            hiddenUrl.value = val;
            hiddenText.value = '';
        } else {
            hiddenText.value = val;
            hiddenUrl.value = '';
        }

        const btn = document.getElementById('btn-submit');
        btn.disabled = true;
        btn.textContent = 'Analyzing...';
    });

    function toggleCard(id) {
        document.getElementById('scan-' + id).classList.toggle('expanded');
    }

    function toggleAccordion(btn) {
        btn.closest('.accordion').classList.toggle('open');
    }

    @if (session('latest_scan_id'))
        document.getElementById('scan-{{ session('latest_scan_id') }}')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    @endif
</script>
@endsection
VIEW

echo "  -> resources/views/scans/index.blade.php"

echo ""
echo "=== Update Complete ==="
echo "Refresh https://postg.app to see changes."
echo ""
echo "Changes:"
echo "  - Favicon added (POSTGUARDlogo.png)"
echo "  - GitHub repo link in nav"
echo "  - Single smart input (auto-detects URL vs text)"
echo "  - Brighter text across all muted/faint elements"
echo "  - Footer with attribution"
echo ""
echo "NOTE: Update the GitHub URL in the nav to match your actual repo URL."
