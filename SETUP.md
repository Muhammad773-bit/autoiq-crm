# AutoIQ CRM — Setup Guide

> UAE Automotive Market CRM & AI Sales Intelligence Platform

---

## Prerequisites

- [Supabase](https://supabase.com) account (free tier works for development)
- [Railway](https://railway.app) account (for n8n and Python workers)
- [Anthropic](https://console.anthropic.com) API key (for Claude AI)
- [Apify](https://apify.com) account + token (for Google Maps scraping)
- [Google Cloud Console](https://console.cloud.google.com) OAuth2 credentials (for Gmail)

---

## Step 1 — Database Setup (Supabase)

1. Create a new Supabase project at https://supabase.com
2. Go to **SQL Editor** in the Supabase dashboard
3. Open `supabase_schema.sql` from this repo
4. Run the entire SQL file — it creates:
   - Extensions (`uuid-ossp`, `pg_trgm`)
   - 8 ENUM types
   - 12 tables with indexes
   - Row Level Security policies
   - 5 dashboard views
   - Services catalog seed data
5. Verify all tables exist under **Table Editor**:
   - `leads`, `activities`, `team_members`, `website_audits`, `social_audits`
   - `email_intelligence`, `competitors`, `proposals`, `email_sequences`
   - `services`, `scraping_jobs`, `follow_up_tasks`

---

## Step 2 — Edge Functions (Supabase)

### Install Supabase CLI

```bash
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

### Set Secrets

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-your-key
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### Deploy Functions

```bash
supabase functions deploy analyze-lead
supabase functions deploy generate-email
supabase functions deploy generate-proposal
```

### Test

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/analyze-lead \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"lead_id": 1}'
```

---

## Step 3 — n8n Automation (Railway)

### Deploy n8n on Railway

1. Go to https://railway.app/new
2. Deploy the official n8n Docker image: `n8nio/n8n`
3. Set environment variables:
   ```
   SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
   ANTHROPIC_API_KEY=sk-ant-your-key
   APIFY_TOKEN=apify_api_your-token
   GMAIL_CLIENT_ID=your-google-client-id
   GMAIL_CLIENT_SECRET=your-google-client-secret
   GENERIC_TIMEZONE=Asia/Dubai
   N8N_WEBHOOK_URL=https://your-n8n.railway.app
   ```

### Import Workflows

1. Open your n8n dashboard
2. Go to **Workflows** → **Import from File**
3. Import each JSON file from `n8n_workflows/`:
   - `01_new_lead_auto_enrichment.json`
   - `02_daily_email_sequence.json`
   - `03_followup_sequence.json`
   - `04_apify_scraper_pipeline.json`
   - `05_weekly_manager_report.json`
4. Configure credentials in each workflow:
   - **Supabase**: Add your Supabase API credentials
   - **Gmail OAuth2**: Connect your Gmail account
5. Activate all 5 workflows

### Test Workflow 1

```bash
curl -X POST https://your-n8n.railway.app/webhook/new-lead \
  -H "Content-Type: application/json" \
  -d '{"id": 1, "website": "https://example.com", "emirate": "Dubai"}'
```

---

## Step 4 — Python Scraping Workers (Railway)

### Local Development

```bash
cd autoiq-scrapers
pip install -r requirements.txt
playwright install chromium
cp ../.env.example .env
# Edit .env with your credentials
python main.py
```

### Deploy to Railway

1. Create a new Railway service
2. Connect this repo or deploy the `autoiq-scrapers/` directory
3. Set environment variables:
   ```
   SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   SUPABASE_KEY=your-service-role-key
   ANTHROPIC_API_KEY=sk-ant-your-key
   APIFY_TOKEN=apify_api_your-token
   ```
4. Set start command: `python main.py`

---

## Step 5 — Frontend Integration

1. Open `UAE_AutoCRM_Dashboard_connected.html`
2. Replace the config at the top of the `<script>` block:
   ```javascript
   const SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
   const SUPABASE_ANON_KEY = 'your-anon-key';
   ```
3. Do the same in `UAE_AutoCRM_LeadDetail_connected.html`
4. Open the Dashboard HTML in a browser to verify KPIs load

---

## Step 6 — Verification Checklist

Run through these checks after setup:

- [ ] All 12 tables visible in Supabase Table Editor
- [ ] Services catalog has 12 rows (check `services` table)
- [ ] Dashboard views return data (`dashboard_kpis`, `pipeline_stage_counts`)
- [ ] Edge Function `analyze-lead` returns AI analysis
- [ ] Edge Function `generate-email` returns subject + body
- [ ] Edge Function `generate-proposal` saves to proposals table
- [ ] n8n Workflow 1 webhook responds and creates follow-up task
- [ ] n8n Workflow 4 (Apify) scrapes and inserts leads
- [ ] Dashboard HTML loads real KPI data
- [ ] Lead Detail HTML loads all 6 tabs from database
- [ ] Python worker runs and audits websites
- [ ] Realtime: insert a lead in Supabase → dashboard updates without refresh

---

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Frontend   │ ──► │  Supabase    │ ◄── │  n8n (Railway)  │
│  HTML/JS    │     │  PostgreSQL  │     │  5 Workflows    │
│             │     │  Edge Funcs  │     │                 │
└─────────────┘     │  Auth + RLS  │     └────────┬────────┘
                    │  Realtime    │              │
                    └──────┬───────┘     ┌────────▼────────┐
                           │             │  Python Workers  │
                    ┌──────▼───────┐     │  (Railway)       │
                    │  Anthropic   │     │  Website Audit   │
                    │  Claude API  │     │  Social Audit    │
                    │              │     │  Email Discovery │
                    └──────────────┘     └─────────────────┘
```

---

## File Structure

```
autoiq-crm/
├── supabase_schema.sql                         # Complete database schema
├── supabase/functions/
│   ├── analyze-lead/index.ts                   # AI lead analysis
│   ├── generate-email/index.ts                 # AI email generation
│   └── generate-proposal/index.ts              # AI proposal generation
├── n8n_workflows/
│   ├── 01_new_lead_auto_enrichment.json        # Webhook → AI → Assign
│   ├── 02_daily_email_sequence.json            # 9AM → Generate → Send
│   ├── 03_followup_sequence.json               # 10AM → Follow-up → Recycle
│   ├── 04_apify_scraper_pipeline.json          # 2AM → Scrape → Insert
│   └── 05_weekly_manager_report.json           # Sunday 8PM → Report
├── autoiq-scrapers/
│   ├── main.py                                 # Worker entry point
│   ├── requirements.txt                        # Python dependencies
│   ├── config/settings.py                      # Environment config
│   ├── database/supabase_client.py             # DB operations
│   ├── scrapers/
│   │   ├── website_checker.py                  # Website audit scraper
│   │   ├── email_extractor.py                  # Email discovery
│   │   ├── instagram_scraper.py                # Instagram analysis
│   │   ├── facebook_scraper.py                 # Facebook analysis
│   │   └── google_maps.py                      # Google Maps extraction
│   └── workers/
│       ├── website_audit_worker.py             # Batch website audits
│       ├── social_audit_worker.py              # Batch social audits
│       └── email_discovery_worker.py           # Batch email discovery
├── UAE_AutoCRM_Dashboard_connected.html         # Dashboard with backend
├── UAE_AutoCRM_LeadDetail_connected.html        # Lead detail with backend
├── .env.example                                 # Environment template
└── SETUP.md                                     # This file
```

---

## Support

- **Supabase**: https://supabase.com/docs
- **n8n**: https://docs.n8n.io
- **Anthropic**: https://docs.anthropic.com
- **Railway**: https://docs.railway.app

---

*AutoIQ CRM — Built for UAE Automotive Market*
