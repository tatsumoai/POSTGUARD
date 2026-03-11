#!/bin/bash
# PostGuard Setup Script
# Run this from ~/postguard on the server

set -e
echo "=== PostGuard Setup ==="

# ── 1. Migration ──────────────────────────────────────────────────────
echo "[1/8] Writing migration..."

# Find the migration file that was created
MIGRATION_FILE=$(ls database/migrations/*_create_scans_table.php 2>/dev/null | head -1)

if [ -z "$MIGRATION_FILE" ]; then
  echo "ERROR: Migration file not found. Run: php artisan make:model Scan -mc"
  exit 1
fi

cat > "$MIGRATION_FILE" << 'MIGRATION'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('scans', function (Blueprint $table) {
            $table->id();
            $table->string('company')->nullable();
            $table->string('title')->nullable();
            $table->string('source')->nullable();
            $table->text('url')->nullable();
            $table->longText('input_text');
            $table->integer('score')->default(0);
            $table->string('verdict')->default('UNKNOWN');
            $table->integer('ai_content_score')->nullable();
            $table->string('salary')->nullable();
            $table->json('flags')->nullable();
            $table->json('positives')->nullable();
            $table->json('cautions')->nullable();
            $table->text('summary')->nullable();
            $table->timestamp('scanned_at')->useCurrent();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('scans');
    }
};
MIGRATION

echo "  -> $MIGRATION_FILE"

# ── 2. Model ──────────────────────────────────────────────────────────
echo "[2/8] Writing Scan model..."

cat > app/Models/Scan.php << 'MODEL'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Scan extends Model
{
    protected $fillable = [
        'company',
        'title',
        'source',
        'url',
        'input_text',
        'score',
        'verdict',
        'ai_content_score',
        'salary',
        'flags',
        'positives',
        'cautions',
        'summary',
        'scanned_at',
    ];

    protected $casts = [
        'flags' => 'array',
        'positives' => 'array',
        'cautions' => 'array',
        'scanned_at' => 'datetime',
    ];
}
MODEL

echo "  -> app/Models/Scan.php"

# ── 3. Claude Service ─────────────────────────────────────────────────
echo "[3/8] Writing ClaudeService..."

mkdir -p app/Services

cat > app/Services/ClaudeService.php << 'SERVICE'
<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ClaudeService
{
    private string $apiKey;
    private string $model = 'claude-sonnet-4-20250514';
    private string $apiUrl = 'https://api.anthropic.com/v1/messages';

    public function __construct()
    {
        $this->apiKey = config('services.anthropic.api_key');
    }

    public function analyzeJobPosting(string $text): ?array
    {
        $systemPrompt = $this->buildSystemPrompt();

        try {
            $response = Http::withHeaders([
                'x-api-key' => $this->apiKey,
                'anthropic-version' => '2023-06-01',
                'content-type' => 'application/json',
            ])->timeout(60)->post($this->apiUrl, [
                'model' => $this->model,
                'max_tokens' => 2048,
                'system' => $systemPrompt,
                'messages' => [
                    [
                        'role' => 'user',
                        'content' => "Analyze this job posting:\n\n" . $text,
                    ],
                ],
            ]);

            if (!$response->successful()) {
                Log::error('Claude API error', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);
                return null;
            }

            $data = $response->json();
            $content = $data['content'][0]['text'] ?? '';

            // Extract JSON from response
            $json = $content;
            if (preg_match('/```json\s*(.*?)\s*```/s', $content, $matches)) {
                $json = $matches[1];
            } elseif (preg_match('/\{.*\}/s', $content, $matches)) {
                $json = $matches[0];
            }

            $result = json_decode($json, true);

            if (json_last_error() !== JSON_ERROR_NONE) {
                Log::error('Claude JSON parse error', [
                    'error' => json_last_error_msg(),
                    'content' => $content,
                ]);
                return null;
            }

            return $result;

        } catch (\Exception $e) {
            Log::error('Claude API exception', [
                'message' => $e->getMessage(),
            ]);
            return null;
        }
    }

    public function fetchUrl(string $url): ?string
    {
        try {
            $response = Http::withHeaders([
                'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            ])->timeout(10)->get($url);

            if (!$response->successful()) {
                return null;
            }

            $html = $response->body();

            // Strip scripts, styles, and HTML tags
            $text = preg_replace('/<script\b[^>]*>.*?<\/script>/si', '', $html);
            $text = preg_replace('/<style\b[^>]*>.*?<\/style>/si', '', $text);
            $text = preg_replace('/<nav\b[^>]*>.*?<\/nav>/si', '', $text);
            $text = preg_replace('/<footer\b[^>]*>.*?<\/footer>/si', '', $text);
            $text = strip_tags($text);
            $text = html_entity_decode($text, ENT_QUOTES, 'UTF-8');
            $text = preg_replace('/\s+/', ' ', $text);
            $text = trim($text);

            // If too short, probably blocked
            if (strlen($text) < 100) {
                return null;
            }

            // Cap at ~8000 chars to avoid massive token usage
            return substr($text, 0, 8000);

        } catch (\Exception $e) {
            Log::warning('URL fetch failed', [
                'url' => $url,
                'error' => $e->getMessage(),
            ]);
            return null;
        }
    }

    private function buildSystemPrompt(): string
    {
        return <<<'PROMPT'
You are PostGuard, an AI job posting analyst. Your job is to evaluate job listings for legitimacy, red flags, and AI-generated content.

Analyze the job posting and return ONLY valid JSON (no markdown, no explanation, no code fences) with this exact structure:

{
  "company": "Company name from the posting",
  "title": "Job title from the posting",
  "salary": "Salary/compensation if mentioned, otherwise null",
  "score": 0-100 integer. 90-100 = clearly legitimate. 70-89 = mostly legit with minor concerns. 50-69 = proceed with caution. 30-49 = suspicious. 0-29 = likely scam,
  "verdict": "LEGIT" or "CAUTION" or "SUSPICIOUS" or "SCAM",
  "ai_content_score": 0-100 integer estimating how likely the posting text was written by AI. 0 = clearly human. 100 = clearly AI generated,
  "flags": ["Array of specific red flag strings. Be concrete, not vague. Example: 'PayPal-only payment avoids standard payroll protections' not just 'unusual payment method'"],
  "positives": ["Array of specific positive signal strings. Example: 'Named hiring manager with verifiable LinkedIn profile' not just 'seems legit'"],
  "cautions": ["Array of things that are not red flags but worth noting. Example: 'Very broad salary range suggests compensation is negotiation-dependent'"],
  "summary": "3-4 sentence analysis written like a knowledgeable friend giving advice. Be direct and specific. Not robotic. No filler phrases."
}

Scoring guidelines:
- Transparent salary range with specific numbers: +10
- Named team, manager, or department: +10
- Specific technical requirements (not generic buzzwords): +10
- Verifiable company with funding/size details: +10
- Clear role responsibilities with real tools/technologies mentioned: +10
- PayPal-only or crypto payment: -15
- No company name or vague company info: -20
- Unpaid assessment or trial period before paid work: -10
- "No experience required" for skilled work: -10
- Unrealistic pay for the work described: -15
- Urgency language ("apply now", "limited spots"): -5
- Email address from free provider (gmail, yahoo): -10
- MLM/pyramid language ("build your team", "unlimited earning potential"): -25
- Asks for money upfront: -30

AI content scoring guidelines:
- Formulaic structure with generic benefit language: high AI score
- Specific anecdotes, company voice, personality: low AI score
- Buzzword-heavy with no substance: high AI score
- Technical specificity with real tool names: low AI score

Write like a real person. Never use em-dashes. Never use: crucial, vital, straightforward, robust, leverage, utilize, furthermore, notably, comprehensive, facilitate, delve, foster, ensure, enhance, underscore, prioritize, proactively. No filler phrases like "it's important to note."
PROMPT;
    }
}
SERVICE

echo "  -> app/Services/ClaudeService.php"

# ── 4. Controller ─────────────────────────────────────────────────────
echo "[4/8] Writing ScanController..."

cat > app/Http/Controllers/ScanController.php << 'CONTROLLER'
<?php

namespace App\Http\Controllers;

use App\Models\Scan;
use App\Services\ClaudeService;
use Illuminate\Http\Request;

class ScanController extends Controller
{
    public function index()
    {
        $scans = Scan::orderBy('scanned_at', 'desc')->take(20)->get();
        return view('scans.index', compact('scans'));
    }

    public function analyze(Request $request)
    {
        $request->validate([
            'input_text' => 'required_without:url|nullable|string|min:50',
            'url' => 'required_without:input_text|nullable|url',
        ], [
            'input_text.min' => 'Paste at least 50 characters of the job posting.',
            'input_text.required_without' => 'Paste a job posting or enter a URL.',
            'url.required_without' => 'Enter a URL or paste the job posting text.',
        ]);

        $claude = new ClaudeService();
        $inputText = $request->input('input_text');
        $url = $request->input('url');
        $fetchedFromUrl = false;

        // If URL provided, try to fetch it
        if ($url && !$inputText) {
            $fetched = $claude->fetchUrl($url);
            if ($fetched) {
                $inputText = $fetched;
                $fetchedFromUrl = true;
            } else {
                return back()
                    ->withInput()
                    ->withErrors(['url' => "Couldn't access that URL. The site may be blocking automated access. Try pasting the job posting text instead."]);
            }
        }

        // Analyze with Claude
        $result = $claude->analyzeJobPosting($inputText);

        if (!$result) {
            return back()
                ->withInput()
                ->withErrors(['analysis' => 'Analysis failed. Please try again.']);
        }

        // Store the scan
        $scan = Scan::create([
            'company' => $result['company'] ?? 'Unknown',
            'title' => $result['title'] ?? 'Unknown',
            'source' => $fetchedFromUrl ? parse_url($url, PHP_URL_HOST) : 'Pasted text',
            'url' => $url,
            'input_text' => $inputText,
            'score' => $result['score'] ?? 50,
            'verdict' => $result['verdict'] ?? 'UNKNOWN',
            'ai_content_score' => $result['ai_content_score'] ?? null,
            'salary' => $result['salary'] ?? null,
            'flags' => $result['flags'] ?? [],
            'positives' => $result['positives'] ?? [],
            'cautions' => $result['cautions'] ?? [],
            'summary' => $result['summary'] ?? null,
            'scanned_at' => now(),
        ]);

        return redirect()->route('scans.index')->with('latest_scan_id', $scan->id);
    }

    public function show(Scan $scan)
    {
        return view('scans.show', compact('scan'));
    }

    public function destroy(Scan $scan)
    {
        $scan->delete();
        return redirect()->route('scans.index')->with('status', 'Scan deleted.');
    }
}
CONTROLLER

echo "  -> app/Http/Controllers/ScanController.php"

# ── 5. Routes ─────────────────────────────────────────────────────────
echo "[5/8] Writing routes..."

cat > routes/web.php << 'ROUTES'
<?php

use App\Http\Controllers\ScanController;
use Illuminate\Support\Facades\Route;

Route::get('/', [ScanController::class, 'index'])->name('scans.index');
Route::post('/analyze', [ScanController::class, 'analyze'])->name('scans.analyze');
Route::get('/scan/{scan}', [ScanController::class, 'show'])->name('scans.show');
Route::delete('/scan/{scan}', [ScanController::class, 'destroy'])->name('scans.destroy');
ROUTES

echo "  -> routes/web.php"

# ── 6. Config for Anthropic API ───────────────────────────────────────
echo "[6/8] Adding Anthropic config..."

# Add to config/services.php if not already there
if ! grep -q 'anthropic' config/services.php; then
  sed -i "s/\];/\n    'anthropic' => [\n        'api_key' => env('ANTHROPIC_API_KEY'),\n    ],\n\n];/" config/services.php
  echo "  -> config/services.php updated"
else
  echo "  -> config/services.php already has anthropic config"
fi

# ── 7. Blade Layout ───────────────────────────────────────────────────
echo "[7/8] Writing Blade views..."

mkdir -p resources/views/scans
mkdir -p resources/views/layouts

cat > resources/views/layouts/app.blade.php << 'LAYOUT'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PostGuard - Job Posting Analyzer</title>
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
            --text: rgba(255,255,255,0.9);
            --text-muted: rgba(255,255,255,0.5);
            --text-faint: rgba(255,255,255,0.25);
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
        .nav-brand { display: flex; align-items: center; gap: 12px; text-decoration: none; color: var(--text); }
        .nav-logo { width: 36px; height: 36px; border-radius: 10px; background: linear-gradient(135deg, var(--blue), var(--green)); display: flex; align-items: center; justify-content: center; }
        .nav-title { font-size: 18px; font-weight: 700; letter-spacing: -0.02em; }
        .nav-badge { font-size: 10px; padding: 3px 8px; border-radius: 6px; background: rgba(59,130,246,0.1); border: 1px solid rgba(59,130,246,0.2); color: #93c5fd; font-family: var(--font-mono); font-weight: 700; }
        .nav-stats { font-size: 12px; color: var(--text-faint); font-family: var(--font-mono); }
        .container { max-width: 780px; margin: 0 auto; padding: 32px 24px; }
        .page-title { font-size: 28px; font-weight: 700; letter-spacing: -0.02em; margin-bottom: 6px; }
        .page-subtitle { font-size: 14px; color: var(--text-muted); margin-bottom: 20px; }
        .input-card { border-radius: 14px; background: var(--surface); border: 1px solid var(--border); overflow: hidden; margin-bottom: 32px; }
        .input-tabs { display: flex; border-bottom: 1px solid rgba(255,255,255,0.05); }
        .input-tab { flex: 1; padding: 12px 20px; background: none; border: none; color: var(--text-faint); font-family: var(--font-body); font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.2s; border-bottom: 2px solid transparent; }
        .input-tab.active { color: var(--blue); border-bottom-color: var(--blue); background: rgba(59,130,246,0.05); }
        .input-panel { display: none; }
        .input-panel.active { display: block; }
        textarea, .url-input { width: 100%; padding: 16px 20px; background: transparent; border: none; color: var(--text); font-size: 14px; line-height: 1.6; font-family: var(--font-body); resize: vertical; outline: none; }
        textarea { min-height: 140px; }
        textarea::placeholder, .url-input::placeholder { color: rgba(255,255,255,0.2); }
        .input-footer { display: flex; align-items: center; justify-content: space-between; padding: 12px 20px; border-top: 1px solid rgba(255,255,255,0.05); }
        .word-count { font-size: 11px; color: var(--text-faint); font-family: var(--font-mono); }
        .btn-analyze { padding: 10px 28px; border-radius: 10px; border: none; background: linear-gradient(135deg, var(--blue), var(--green)); color: #fff; font-size: 13px; font-weight: 700; font-family: var(--font-body); cursor: pointer; transition: all 0.2s; letter-spacing: 0.01em; }
        .btn-analyze:hover { opacity: 0.9; transform: translateY(-1px); }
        .btn-analyze:disabled { background: rgba(255,255,255,0.06); color: var(--text-faint); cursor: not-allowed; transform: none; }
        .error-bar { padding: 14px 20px; background: rgba(239,68,68,0.1); border: 1px solid rgba(239,68,68,0.2); border-radius: 10px; color: #fca5a5; font-size: 13px; margin-bottom: 20px; }
        .status-bar { padding: 14px 20px; background: rgba(34,197,94,0.1); border: 1px solid rgba(34,197,94,0.2); border-radius: 10px; color: #86efac; font-size: 13px; margin-bottom: 20px; }
        .section-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
        .section-title { font-size: 16px; font-weight: 700; color: rgba(255,255,255,0.7); }
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
        .ai-bar-note { font-size: 10px; color: var(--text-faint); margin-top: 4px; }
        .accordion { border-radius: 10px; background: var(--surface); border: 1px solid rgba(255,255,255,0.06); overflow: hidden; }
        .accordion-header { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; background: none; border: none; color: rgba(255,255,255,0.7); cursor: pointer; font-family: var(--font-body); font-size: 13px; font-weight: 600; }
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
        .summary-text { font-size: 13px; line-height: 1.7; color: rgba(255,255,255,0.65); }
        .card-actions { display: flex; justify-content: flex-end; gap: 8px; padding-top: 12px; border-top: 1px solid rgba(255,255,255,0.04); }
        .btn-sm { padding: 6px 14px; border-radius: 8px; font-size: 11px; font-family: var(--font-mono); cursor: pointer; transition: all 0.2s; border: 1px solid rgba(255,255,255,0.1); background: rgba(255,255,255,0.04); color: var(--text-muted); text-decoration: none; }
        .btn-sm:hover { background: rgba(255,255,255,0.08); }
        .btn-danger { border-color: rgba(239,68,68,0.2); color: #fca5a5; }
        .btn-danger:hover { background: rgba(239,68,68,0.1); }
        .empty-state { text-align: center; padding: 60px 20px; color: var(--text-faint); font-size: 14px; }
        .empty-icon { font-size: 40px; margin-bottom: 12px; opacity: 0.3; }
        @media (max-width: 640px) { .nav { padding: 12px 16px; } .container { padding: 20px 16px; } .page-title { font-size: 22px; } .scan-card-header { padding: 16px; gap: 14px; } .card-body { padding: 0 16px 16px; padding-top: 16px; } .card-meta { flex-wrap: wrap; gap: 6px; } }
    </style>
</head>
<body>
    <nav class="nav">
        <a href="/" class="nav-brand">
            <div class="nav-logo">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                </svg>
            </div>
            <span class="nav-title">PostGuard</span>
            <span class="nav-badge">BETA</span>
        </a>
        <div class="nav-stats">
            {{ \App\Models\Scan::whereDate('created_at', today())->count() }} scans today
        </div>
    </nav>

    <div class="container">
        @yield('content')
    </div>

    @yield('scripts')
</body>
</html>
LAYOUT

echo "  -> resources/views/layouts/app.blade.php"

# ── 8. Main View ──────────────────────────────────────────────────────
echo "[8/8] Writing main view..."

cat > resources/views/scans/index.blade.php << 'VIEW'
@extends('layouts.app')

@section('content')
    <h1 class="page-title">Scan a job posting</h1>
    <p class="page-subtitle">Paste the full job description or a link. PostGuard will analyze it for legitimacy, red flags, and AI-generated content.</p>

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
        <div class="input-tabs">
            <button class="input-tab active" onclick="switchTab('text')" id="tab-text">Paste Text</button>
            <button class="input-tab" onclick="switchTab('url')" id="tab-url">Paste Link</button>
        </div>

        <form method="POST" action="{{ route('scans.analyze') }}" id="scan-form">
            @csrf
            <div class="input-panel active" id="panel-text">
                <textarea name="input_text" id="input-text" placeholder="Paste the full job posting text here...">{{ old('input_text') }}</textarea>
            </div>

            <div class="input-panel" id="panel-url">
                <input type="url" name="url" class="url-input" placeholder="https://example.com/jobs/posting-123" value="{{ old('url') }}">
            </div>

            <div class="input-footer">
                <span class="word-count" id="word-count"></span>
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
    function switchTab(tab) {
        document.querySelectorAll('.input-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.input-panel').forEach(p => p.classList.remove('active'));
        document.getElementById('tab-' + tab).classList.add('active');
        document.getElementById('panel-' + tab).classList.add('active');
        if (tab === 'text') {
            document.querySelector('.url-input').value = '';
        } else {
            document.getElementById('input-text').value = '';
        }
    }

    function toggleCard(id) {
        document.getElementById('scan-' + id).classList.toggle('expanded');
    }

    function toggleAccordion(btn) {
        btn.closest('.accordion').classList.toggle('open');
    }

    const textarea = document.getElementById('input-text');
    const wordCount = document.getElementById('word-count');
    if (textarea) {
        textarea.addEventListener('input', function() {
            const words = this.value.trim().split(/\s+/).filter(Boolean).length;
            wordCount.textContent = words > 0 ? words + ' words' : '';
        });
    }

    document.getElementById('scan-form').addEventListener('submit', function() {
        const btn = document.getElementById('btn-submit');
        btn.disabled = true;
        btn.textContent = 'Analyzing...';
    });

    @if (session('latest_scan_id'))
        document.getElementById('scan-{{ session('latest_scan_id') }}')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    @endif
</script>
@endsection
VIEW

echo "  -> resources/views/scans/index.blade.php"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Add your Anthropic API key to .env:"
echo "     echo 'ANTHROPIC_API_KEY=your-key-here' >> .env"
echo "  2. Run the migration:"
echo "     php artisan migrate"
echo "  3. Clear the config cache:"
echo "     php artisan config:clear"
echo "  4. Restart nginx:"
echo "     sudo systemctl restart nginx"
echo ""
echo "Then visit http://142.93.113.189"
