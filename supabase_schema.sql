-- ============================================================
-- AutoIQ CRM — Supabase Database Schema
-- UAE Automotive Market CRM & AI Sales Intelligence Platform
-- ============================================================
-- Run ALL SQL in Supabase SQL Editor in this exact order.
-- ============================================================

-- 1.1 — Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 1.2 — ENUM Types
CREATE TYPE dealer_type_enum AS ENUM (
  'used_car', 'showroom', 'broker', 'rental',
  'importer', 'exporter', 'workshop', 'other'
);

CREATE TYPE emirate_enum AS ENUM (
  'Dubai', 'Sharjah', 'Abu Dhabi', 'Ajman',
  'Ras Al Khaimah', 'Fujairah', 'Umm Al Quwain'
);

CREATE TYPE pipeline_stage_enum AS ENUM (
  'new', 'verified', 'scraped', 'ready_to_pitch',
  'contacted', 'interested', 'meeting_booked',
  'proposal_sent', 'negotiation', 'won', 'lost', 'recycle'
);

CREATE TYPE website_status_enum AS ENUM (
  'live', 'dead', 'none', 'redirects', 'unknown'
);

CREATE TYPE activity_type_enum AS ENUM (
  'call', 'email', 'whatsapp', 'meeting',
  'note', 'stage_change', 'system', 'proposal'
);

CREATE TYPE call_outcome_enum AS ENUM (
  'connected', 'no_answer', 'callback_requested',
  'not_interested', 'interested', 'wrong_number', 'voicemail'
);

CREATE TYPE budget_tier_enum AS ENUM (
  'low', 'medium', 'high', 'enterprise'
);

CREATE TYPE scraping_status_enum AS ENUM (
  'pending', 'running', 'complete', 'failed', 'partial'
);

CREATE TYPE agent_role_enum AS ENUM (
  'super_admin', 'sales_manager', 'senior_agent',
  'agent', 'scraping_operator', 'read_only'
);

-- 1.3 — TEAM MEMBERS TABLE (create before leads, FK dependency)
CREATE TABLE team_members (
  id                    BIGSERIAL PRIMARY KEY,
  user_id               UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name             TEXT NOT NULL,
  email                 TEXT UNIQUE NOT NULL,
  phone                 TEXT,
  role                  agent_role_enum DEFAULT 'agent',
  avatar_initials       TEXT,
  is_active             BOOLEAN DEFAULT true,
  max_leads             INT DEFAULT 100,
  current_lead_count    INT DEFAULT 0,
  city_assignment       emirate_enum[],
  monthly_target        INT DEFAULT 25,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- 1.4 — MASTER LEADS TABLE
CREATE TABLE leads (
  -- Identity
  id                    BIGSERIAL PRIMARY KEY,
  lead_uid              UUID DEFAULT uuid_generate_v4() UNIQUE,
  business_name         TEXT NOT NULL,
  arabic_name           TEXT,
  legal_name            TEXT,
  trade_name            TEXT,
  dealer_type           dealer_type_enum DEFAULT 'used_car',
  franchise_type        TEXT,
  license_number        TEXT,
  vat_registered        BOOLEAN DEFAULT false,
  vat_trn               TEXT,
  years_in_market       INT,
  company_size          TEXT,
  branch_count          INT DEFAULT 1,

  -- Location
  country               TEXT DEFAULT 'UAE',
  emirate               emirate_enum,
  city                  TEXT,
  area                  TEXT,
  zone                  TEXT,
  address               TEXT,
  google_maps_url       TEXT,
  latitude              NUMERIC(10,7),
  longitude             NUMERIC(10,7),
  landmark              TEXT,

  -- Contacts
  owner_name            TEXT,
  director_name         TEXT,
  sales_manager         TEXT,
  marketing_manager     TEXT,
  phone                 TEXT,
  mobile                TEXT,
  whatsapp              TEXT,
  email_primary         TEXT,
  email_secondary       TEXT,
  email_info            TEXT,
  email_sales           TEXT,
  email_admin           TEXT,
  gmail_found           TEXT,
  email_verified        BOOLEAN DEFAULT false,
  email_source          TEXT,
  preferred_outreach_email TEXT,
  best_contact_time     TEXT,
  preferred_language    TEXT DEFAULT 'English',
  contact_form_url      TEXT,

  -- Website
  website               TEXT,
  website_status        website_status_enum DEFAULT 'unknown',
  website_score         INT DEFAULT 0 CHECK (website_score BETWEEN 0 AND 100),
  seo_score             INT DEFAULT 0 CHECK (seo_score BETWEEN 0 AND 100),
  mobile_score          INT DEFAULT 0 CHECK (mobile_score BETWEEN 0 AND 100),
  speed_score           INT DEFAULT 0 CHECK (speed_score BETWEEN 0 AND 100),
  ux_score              INT DEFAULT 0 CHECK (ux_score BETWEEN 0 AND 100),
  cms                   TEXT,
  https_enabled         BOOLEAN,
  domain_age_years      INT,
  hosting_provider      TEXT,

  -- Google Business Profile
  google_maps_exists    BOOLEAN DEFAULT false,
  google_rating         NUMERIC(2,1) CHECK (google_rating BETWEEN 0 AND 5),
  google_reviews        INT DEFAULT 0,
  gbp_photos_count      INT DEFAULT 0,
  gbp_owner_replies     BOOLEAN DEFAULT false,
  gbp_last_review_date  DATE,

  -- Instagram
  instagram_handle      TEXT,
  instagram_url         TEXT,
  instagram_followers   INT DEFAULT 0,
  instagram_posts       INT DEFAULT 0,
  instagram_avg_likes   INT DEFAULT 0,
  instagram_engagement  NUMERIC(5,2) DEFAULT 0,
  instagram_score       INT DEFAULT 0 CHECK (instagram_score BETWEEN 0 AND 100),
  instagram_last_post   DATE,
  instagram_posting_freq TEXT,
  instagram_whatsapp_bio BOOLEAN DEFAULT false,
  instagram_email_bio   TEXT,

  -- Facebook
  facebook_url          TEXT,
  facebook_followers    INT DEFAULT 0,
  facebook_likes        INT DEFAULT 0,
  facebook_review_score NUMERIC(2,1),
  facebook_score        INT DEFAULT 0 CHECK (facebook_score BETWEEN 0 AND 100),
  facebook_last_post    DATE,
  facebook_messenger    BOOLEAN DEFAULT false,
  facebook_email        TEXT,

  -- LinkedIn
  linkedin_url          TEXT,
  linkedin_employees    INT DEFAULT 0,
  linkedin_owner_url    TEXT,
  linkedin_score        INT DEFAULT 0,

  -- Social Overall
  social_presence_score INT DEFAULT 0 CHECK (social_presence_score BETWEEN 0 AND 100),
  branding_score        INT DEFAULT 0 CHECK (branding_score BETWEEN 0 AND 100),

  -- Competitor Intel
  competitor_1_name     TEXT,
  competitor_1_website  TEXT,
  competitor_1_score    INT,
  competitor_1_reviews  INT,
  competitor_1_why_winning TEXT,
  competitor_2_name     TEXT,
  competitor_2_website  TEXT,
  competitor_2_score    INT,
  competitor_3_name     TEXT,
  competitor_3_website  TEXT,

  -- Business Operations
  cars_in_stock         INT,
  luxury_inventory      INT DEFAULT 0,
  economy_inventory     INT DEFAULT 0,
  electric_cars         INT DEFAULT 0,
  finance_available     BOOLEAN DEFAULT false,
  insurance_available   BOOLEAN DEFAULT false,
  trade_in_available    BOOLEAN DEFAULT false,
  export_available      BOOLEAN DEFAULT false,

  -- Commercial Intelligence
  estimated_revenue_tier TEXT,
  estimated_monthly_leads INT,
  estimated_staff_count INT,
  likely_marketing_spend TEXT,
  growth_potential_score INT DEFAULT 0,

  -- AI Analysis
  ai_analysis           TEXT,
  why_behind            TEXT,
  growth_opportunities  TEXT,
  pitch_summary         TEXT,
  recommended_services  TEXT[],
  priority_package      TEXT,

  -- AI Scores
  lead_score            INT DEFAULT 0 CHECK (lead_score BETWEEN 0 AND 100),
  close_probability     INT DEFAULT 0 CHECK (close_probability BETWEEN 0 AND 100),
  urgency_score         INT DEFAULT 0 CHECK (urgency_score BETWEEN 0 AND 100),
  digital_weakness_score INT DEFAULT 0 CHECK (digital_weakness_score BETWEEN 0 AND 100),
  email_reachability_score INT DEFAULT 0 CHECK (email_reachability_score BETWEEN 0 AND 100),
  estimated_budget_tier budget_tier_enum DEFAULT 'medium',

  -- CRM Pipeline
  status                pipeline_stage_enum DEFAULT 'new',
  pipeline_stage        TEXT DEFAULT 'new',
  assigned_agent_id     BIGINT REFERENCES team_members(id),
  followup_count        INT DEFAULT 0,
  last_contacted        TIMESTAMPTZ,
  last_contacted_channel TEXT,
  next_followup_date    DATE,

  -- Email Outreach
  email_sequence_stage  INT DEFAULT 0,
  email_opened          BOOLEAN DEFAULT false,
  email_replied         BOOLEAN DEFAULT false,
  email_bounce          BOOLEAN DEFAULT false,

  -- Loss Tracking
  loss_reason           TEXT,
  loss_notes            TEXT,

  -- Source & Scraping
  source                TEXT DEFAULT 'manual',
  scraping_status       scraping_status_enum DEFAULT 'pending',
  scraping_completed_at TIMESTAMPTZ,
  ai_analyzed_at        TIMESTAMPTZ,

  -- Timestamps
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast filtering
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_emirate ON leads(emirate);
CREATE INDEX idx_leads_lead_score ON leads(lead_score DESC);
CREATE INDEX idx_leads_agent ON leads(assigned_agent_id);
CREATE INDEX idx_leads_followup ON leads(next_followup_date);
CREATE INDEX idx_leads_source ON leads(source);
CREATE INDEX idx_leads_created ON leads(created_at DESC);
CREATE INDEX idx_leads_name_search ON leads USING gin(business_name gin_trgm_ops);

-- 1.5 — ACTIVITIES TABLE (Call log, emails, notes, stage changes)
CREATE TABLE activities (
  id                BIGSERIAL PRIMARY KEY,
  lead_id           BIGINT REFERENCES leads(id) ON DELETE CASCADE,
  agent_id          BIGINT REFERENCES team_members(id),
  activity_type     activity_type_enum NOT NULL,
  title             TEXT,
  notes             TEXT,
  outcome           call_outcome_enum,
  duration_minutes  INT,
  stage_before      TEXT,
  stage_after       TEXT,
  email_subject     TEXT,
  email_status      TEXT,
  next_action       TEXT,
  next_action_date  DATE,
  metadata          JSONB DEFAULT '{}',
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_activities_lead ON activities(lead_id);
CREATE INDEX idx_activities_agent ON activities(agent_id);
CREATE INDEX idx_activities_type ON activities(activity_type);
CREATE INDEX idx_activities_created ON activities(created_at DESC);

-- 1.6 — WEBSITE AUDITS TABLE
CREATE TABLE website_audits (
  id                    BIGSERIAL PRIMARY KEY,
  lead_id               BIGINT REFERENCES leads(id) ON DELETE CASCADE,
  audited_at            TIMESTAMPTZ DEFAULT NOW(),

  -- Basic
  url                   TEXT,
  status                website_status_enum,
  https_enabled         BOOLEAN,
  domain_age_years      INT,
  cms                   TEXT,
  hosting_provider      TEXT,
  server_country        TEXT,

  -- Speed
  speed_desktop         INT,
  speed_mobile          INT,
  lcp_desktop           NUMERIC(5,2),
  lcp_mobile            NUMERIC(5,2),

  -- SEO
  title_tags_pct        INT,
  meta_desc_pct         INT,
  h1_count              INT,
  h1_multiple           BOOLEAN DEFAULT false,
  schema_markup         BOOLEAN DEFAULT false,
  sitemap_exists        BOOLEAN DEFAULT false,
  robots_exists         BOOLEAN DEFAULT false,
  indexed_pages         INT,
  backlinks_estimate    INT,
  blog_exists           BOOLEAN DEFAULT false,

  -- UX
  design_score          INT,
  mobile_responsive     BOOLEAN DEFAULT false,
  whatsapp_button       BOOLEAN DEFAULT false,
  call_button           BOOLEAN DEFAULT false,
  live_chat             BOOLEAN DEFAULT false,
  cta_count             INT DEFAULT 0,

  -- Lead Gen
  contact_form          BOOLEAN DEFAULT false,
  inquiry_form          BOOLEAN DEFAULT false,
  finance_calculator    BOOLEAN DEFAULT false,
  test_drive_form       BOOLEAN DEFAULT false,

  -- Inventory
  inventory_online      BOOLEAN DEFAULT false,
  inventory_count       INT,
  search_filters        TEXT,
  price_display         BOOLEAN DEFAULT false,
  emi_calculator        BOOLEAN DEFAULT false,
  video_walkaround      BOOLEAN DEFAULT false,

  -- Technical Issues
  broken_links          INT DEFAULT 0,
  redirect_chains       INT DEFAULT 0,
  mixed_content         BOOLEAN DEFAULT false,

  -- Emails found on website
  emails_found          TEXT[],
  gmail_found           TEXT,

  -- Scores
  overall_score         INT,
  seo_score             INT,
  mobile_score          INT,
  speed_score           INT,
  ux_score              INT,
  leadgen_score         INT,

  -- Recommendations
  recommendations       JSONB DEFAULT '[]',

  raw_data              JSONB DEFAULT '{}'
);

CREATE INDEX idx_website_audits_lead ON website_audits(lead_id);

-- 1.7 — SOCIAL AUDITS TABLE
CREATE TABLE social_audits (
  id                      BIGSERIAL PRIMARY KEY,
  lead_id                 BIGINT REFERENCES leads(id) ON DELETE CASCADE,
  audited_at              TIMESTAMPTZ DEFAULT NOW(),

  -- Instagram
  ig_handle               TEXT,
  ig_url                  TEXT,
  ig_followers            INT DEFAULT 0,
  ig_following            INT DEFAULT 0,
  ig_posts                INT DEFAULT 0,
  ig_avg_likes            INT DEFAULT 0,
  ig_avg_comments         NUMERIC(6,1) DEFAULT 0,
  ig_engagement_rate      NUMERIC(5,2) DEFAULT 0,
  ig_posting_freq         TEXT,
  ig_last_post            DATE,
  ig_bio_quality          INT DEFAULT 0,
  ig_whatsapp_bio         BOOLEAN DEFAULT false,
  ig_website_bio          BOOLEAN DEFAULT false,
  ig_email_bio            TEXT,
  ig_reels_usage          BOOLEAN DEFAULT false,
  ig_story_highlights     INT DEFAULT 0,
  ig_paid_ads             BOOLEAN DEFAULT false,
  ig_branding_score       INT DEFAULT 0,
  ig_score                INT DEFAULT 0,

  -- Facebook
  fb_page_url             TEXT,
  fb_followers            INT DEFAULT 0,
  fb_likes                INT DEFAULT 0,
  fb_verified             BOOLEAN DEFAULT false,
  fb_review_score         NUMERIC(2,1),
  fb_review_count         INT DEFAULT 0,
  fb_messenger_response   TEXT,
  fb_cta_type             TEXT,
  fb_email                TEXT,
  fb_posting_freq         TEXT,
  fb_last_post            DATE,
  fb_video_count          INT DEFAULT 0,
  fb_lead_form_ads        BOOLEAN DEFAULT false,
  fb_whatsapp_button      BOOLEAN DEFAULT false,
  fb_branding_score       INT DEFAULT 0,
  fb_score                INT DEFAULT 0,

  -- LinkedIn
  li_company_url          TEXT,
  li_followers            INT DEFAULT 0,
  li_employees            INT DEFAULT 0,
  li_owner_name           TEXT,
  li_owner_url            TEXT,
  li_decision_makers      JSONB DEFAULT '[]',
  li_hiring_active        BOOLEAN DEFAULT false,
  li_growth_signals       TEXT,
  li_public_emails        TEXT[],
  li_score                INT DEFAULT 0,

  -- Overall
  overall_social_score    INT DEFAULT 0,

  raw_data                JSONB DEFAULT '{}'
);

CREATE INDEX idx_social_audits_lead ON social_audits(lead_id);

-- 1.8 — EMAIL INTELLIGENCE TABLE
CREATE TABLE email_intelligence (
  id                      BIGSERIAL PRIMARY KEY,
  lead_id                 BIGINT REFERENCES leads(id) ON DELETE CASCADE,
  discovered_at           TIMESTAMPTZ DEFAULT NOW(),

  -- All emails found
  emails_found            TEXT[],
  gmail_found             TEXT[],
  domain_emails_found     TEXT[],

  -- Classification
  info_email              TEXT,
  sales_email             TEXT,
  admin_email             TEXT,
  owner_gmail             TEXT,
  best_outreach_email     TEXT,
  cold_outreach_priority  TEXT,

  -- Email provider detection
  google_workspace        BOOLEAN DEFAULT false,
  microsoft_365           BOOLEAN DEFAULT false,
  catch_all_domain        BOOLEAN DEFAULT false,

  -- Sources
  source_website          TEXT[],
  source_instagram        TEXT[],
  source_facebook         TEXT[],
  source_linkedin         TEXT[],
  source_google           TEXT[],
  source_manual           TEXT[],

  -- Verification
  verified_emails         TEXT[],
  unverified_emails       TEXT[],
  bounce_emails           TEXT[],

  -- Outreach tracking
  first_email_sent        TIMESTAMPTZ,
  last_email_sent         TIMESTAMPTZ,
  email_opened            BOOLEAN DEFAULT false,
  email_replied           BOOLEAN DEFAULT false,
  bounce_status           TEXT,
  no_response_count       INT DEFAULT 0,
  sequence_stage          INT DEFAULT 0,

  reachability_score      INT DEFAULT 0,
  raw_data                JSONB DEFAULT '{}'
);

CREATE INDEX idx_email_intel_lead ON email_intelligence(lead_id);

-- 1.9 — COMPETITORS TABLE
CREATE TABLE competitors (
  id                  BIGSERIAL PRIMARY KEY,
  lead_id             BIGINT REFERENCES leads(id) ON DELETE CASCADE,
  rank                INT DEFAULT 1,

  name                TEXT,
  website             TEXT,
  emirate             emirate_enum,
  city                TEXT,

  google_rating       NUMERIC(2,1),
  google_reviews      INT,
  google_ranking      INT,

  instagram_followers INT,
  instagram_active    BOOLEAN,

  website_score       INT,
  seo_score           INT,

  has_whatsapp        BOOLEAN DEFAULT false,
  has_inventory_system BOOLEAN DEFAULT false,
  has_emi_calculator  BOOLEAN DEFAULT false,
  has_live_chat       BOOLEAN DEFAULT false,

  ad_presence         BOOLEAN DEFAULT false,
  branding_strength   TEXT,

  why_winning         TEXT,
  their_advantages    TEXT[],

  scraped_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_competitors_lead ON competitors(lead_id);

-- 1.10 — PROPOSALS TABLE
CREATE TABLE proposals (
  id                  BIGSERIAL PRIMARY KEY,
  lead_id             BIGINT REFERENCES leads(id) ON DELETE CASCADE,
  agent_id            BIGINT REFERENCES team_members(id),

  proposal_ref        TEXT UNIQUE,
  version             INT DEFAULT 1,
  status              TEXT DEFAULT 'draft',

  services_included   TEXT[],
  one_time_total_aed  NUMERIC(10,2),
  monthly_total_aed   NUMERIC(10,2),

  roi_conservative    TEXT,
  roi_realistic       TEXT,
  roi_optimistic      TEXT,

  roadmap_month1      TEXT,
  roadmap_month2      TEXT,
  roadmap_month3      TEXT,

  ai_generated_content JSONB DEFAULT '{}',

  pdf_url             TEXT,
  sent_at             TIMESTAMPTZ,
  viewed_at           TIMESTAMPTZ,

  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 1.11 — EMAIL SEQUENCES TABLE
CREATE TABLE email_sequences (
  id                  BIGSERIAL PRIMARY KEY,
  lead_id             BIGINT REFERENCES leads(id) ON DELETE CASCADE,
  agent_id            BIGINT REFERENCES team_members(id),

  sequence_name       TEXT,
  current_step        INT DEFAULT 0,
  status              TEXT DEFAULT 'active',

  step_1_sent_at      TIMESTAMPTZ,
  step_1_opened       BOOLEAN DEFAULT false,
  step_2_due          DATE,
  step_2_sent_at      TIMESTAMPTZ,
  step_2_opened       BOOLEAN DEFAULT false,
  step_3_due          DATE,
  step_3_sent_at      TIMESTAMPTZ,
  step_3_opened       BOOLEAN DEFAULT false,

  reply_received      BOOLEAN DEFAULT false,
  reply_received_at   TIMESTAMPTZ,

  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 1.12 — SERVICES CATALOG TABLE
CREATE TABLE services (
  id                  BIGSERIAL PRIMARY KEY,
  category            TEXT,
  service_name        TEXT NOT NULL,
  solves_problem      TEXT,
  ideal_for           TEXT[],
  price_min_aed       NUMERIC(10,2),
  price_max_aed       NUMERIC(10,2),
  pricing_type        TEXT,
  priority_level      INT DEFAULT 1,
  sales_pitch         TEXT,
  trigger_condition   TEXT,
  is_active           BOOLEAN DEFAULT true,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 1.13 — SCRAPING JOBS TABLE
CREATE TABLE scraping_jobs (
  id                  BIGSERIAL PRIMARY KEY,
  job_uid             UUID DEFAULT uuid_generate_v4(),
  job_name            TEXT,
  search_query        TEXT,
  source              TEXT,
  status              scraping_status_enum DEFAULT 'pending',

  leads_found         INT DEFAULT 0,
  leads_inserted      INT DEFAULT 0,
  leads_duplicate     INT DEFAULT 0,
  leads_failed        INT DEFAULT 0,

  apify_run_id        TEXT,
  apify_dataset_id    TEXT,

  started_at          TIMESTAMPTZ,
  completed_at        TIMESTAMPTZ,
  error_message       TEXT,

  created_by          BIGINT REFERENCES team_members(id),
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 1.14 — FOLLOW-UP TASKS TABLE
CREATE TABLE follow_up_tasks (
  id                  BIGSERIAL PRIMARY KEY,
  lead_id             BIGINT REFERENCES leads(id) ON DELETE CASCADE,
  agent_id            BIGINT REFERENCES team_members(id),

  task_type           TEXT DEFAULT 'follow_up',
  title               TEXT,
  notes               TEXT,
  due_date            DATE NOT NULL,
  due_time            TIME,
  priority            TEXT DEFAULT 'medium',

  status              TEXT DEFAULT 'pending',
  completed_at        TIMESTAMPTZ,

  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tasks_agent_due ON follow_up_tasks(agent_id, due_date);
CREATE INDEX idx_tasks_status ON follow_up_tasks(status);

-- 1.15 — ROW LEVEL SECURITY
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE follow_up_tasks ENABLE ROW LEVEL SECURITY;

-- Policy: agents see only their own leads
CREATE POLICY "agents_own_leads" ON leads
  FOR ALL USING (
    assigned_agent_id IN (
      SELECT id FROM team_members WHERE user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM team_members
      WHERE user_id = auth.uid()
      AND role IN ('super_admin', 'sales_manager', 'senior_agent', 'scraping_operator', 'read_only')
    )
  );

-- Policy: managers see all
CREATE POLICY "managers_all_leads" ON leads
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE user_id = auth.uid()
      AND role IN ('super_admin', 'sales_manager')
    )
  );

-- Policy: team_members visible to authenticated users
CREATE POLICY "team_members_visible" ON team_members
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "team_members_manage" ON team_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE user_id = auth.uid()
      AND role IN ('super_admin', 'sales_manager')
    )
  );

-- Policy: activities visible for own leads
CREATE POLICY "activities_visible" ON activities
  FOR ALL USING (
    lead_id IN (
      SELECT id FROM leads
    )
  );

-- Policy: follow_up_tasks for assigned agent
CREATE POLICY "tasks_own" ON follow_up_tasks
  FOR ALL USING (
    agent_id IN (
      SELECT id FROM team_members WHERE user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM team_members
      WHERE user_id = auth.uid()
      AND role IN ('super_admin', 'sales_manager')
    )
  );

-- 1.16 — DATABASE VIEWS (for fast dashboard queries)

-- Dashboard KPIs view
CREATE OR REPLACE VIEW dashboard_kpis AS
SELECT
  COUNT(*) AS total_leads,
  COUNT(*) FILTER (WHERE lead_score >= 80) AS hot_leads,
  COUNT(*) FILTER (WHERE status = 'won' AND DATE_TRUNC('month', updated_at) = DATE_TRUNC('month', NOW())) AS won_this_month,
  COUNT(*) FILTER (WHERE DATE(last_contacted) = CURRENT_DATE) AS contacted_today,
  COALESCE(SUM(CASE status
    WHEN 'interested' THEN 5000
    WHEN 'meeting_booked' THEN 8000
    WHEN 'proposal_sent' THEN 12000
    WHEN 'negotiation' THEN 18000
    ELSE 0
  END), 0) AS pipeline_value_aed,
  COUNT(*) FILTER (WHERE next_followup_date = CURRENT_DATE AND status NOT IN ('won','lost')) AS followups_due_today,
  COUNT(*) FILTER (WHERE next_followup_date < CURRENT_DATE AND status NOT IN ('won','lost')) AS followups_overdue
FROM leads;

-- Pipeline stage counts
CREATE OR REPLACE VIEW pipeline_stage_counts AS
SELECT
  status,
  COUNT(*) AS lead_count,
  AVG(lead_score)::INT AS avg_score
FROM leads
GROUP BY status
ORDER BY CASE status
  WHEN 'new' THEN 1 WHEN 'verified' THEN 2 WHEN 'scraped' THEN 3
  WHEN 'ready_to_pitch' THEN 4 WHEN 'contacted' THEN 5 WHEN 'interested' THEN 6
  WHEN 'meeting_booked' THEN 7 WHEN 'proposal_sent' THEN 8 WHEN 'negotiation' THEN 9
  WHEN 'won' THEN 10 WHEN 'lost' THEN 11 WHEN 'recycle' THEN 12
END;

-- Hot leads view (for dashboard table)
CREATE OR REPLACE VIEW hot_leads_ranked AS
SELECT
  l.*,
  tm.full_name AS agent_name,
  tm.avatar_initials AS agent_initials
FROM leads l
LEFT JOIN team_members tm ON l.assigned_agent_id = tm.id
WHERE l.lead_score >= 70
  AND l.status NOT IN ('won', 'lost')
ORDER BY l.lead_score DESC, l.next_followup_date ASC NULLS LAST;

-- Leads pending AI analysis
CREATE OR REPLACE VIEW leads_pending_ai AS
SELECT * FROM leads
WHERE scraping_status = 'complete'
  AND ai_analyzed_at IS NULL
  AND status NOT IN ('won', 'lost')
ORDER BY created_at ASC;

-- Today's follow-ups
CREATE OR REPLACE VIEW todays_followups AS
SELECT
  ft.id,
  ft.lead_id,
  ft.agent_id,
  ft.task_type,
  ft.title,
  ft.notes AS task_notes,
  ft.due_date,
  ft.due_time,
  ft.priority,
  ft.status AS task_status,
  ft.completed_at,
  ft.created_at,
  l.business_name,
  l.phone,
  l.whatsapp,
  l.preferred_outreach_email,
  l.lead_score,
  l.status AS lead_status,
  l.emirate,
  tm.full_name AS agent_name
FROM follow_up_tasks ft
JOIN leads l ON ft.lead_id = l.id
JOIN team_members tm ON ft.agent_id = tm.id
WHERE ft.due_date = CURRENT_DATE
  AND ft.status = 'pending'
ORDER BY ft.priority DESC, ft.due_time ASC;

-- 1.17 — SEED SERVICES CATALOG
INSERT INTO services (category, service_name, solves_problem, ideal_for, price_min_aed, price_max_aed, pricing_type, priority_level, sales_pitch, trigger_condition) VALUES
('Website', 'Website Development', 'No online presence', ARRAY['used_car','showroom','broker'], 4500, 8000, 'one_time', 10, 'Your competitors are getting leads 24/7 from their website. You are getting zero.', 'website_status = none OR dead'),
('Website', 'Website Redesign', 'Outdated or poor-performing website', ARRAY['used_car','showroom'], 3500, 6000, 'one_time', 9, 'Your website is losing you 50+ leads/month due to slow speed and no lead forms.', 'website_score < 40'),
('SEO', 'Local SEO + Google Maps', 'Not ranking for local car searches', ARRAY['used_car','showroom','rental'], 1500, 2500, 'monthly', 9, 'Your competitor is #1 for ''used cars Dubai''. You are #7. They get 10x more organic traffic.', 'google_ranking > 5'),
('Social Media', 'Instagram Growth Package', 'Dead or inactive Instagram', ARRAY['used_car','showroom','broker'], 2000, 3500, 'monthly', 8, 'You have followers but zero engagement. Our content plan will reactivate this audience in 30 days.', 'instagram_score < 40 OR instagram_last_post > 14 days ago'),
('Social Media', 'Facebook Marketing', 'No Facebook strategy', ARRAY['used_car','showroom'], 1500, 3000, 'monthly', 7, 'Facebook is where UAE car buyers aged 30-50 research before buying.', 'facebook_score < 40'),
('Advertising', 'Google Ads Management', 'No paid traffic', ARRAY['used_car','showroom','rental'], 1500, 2500, 'monthly', 8, 'Competitors are running ads. You are invisible when buyers search right now.', 'no_paid_ads'),
('Advertising', 'Meta Ads (FB+IG)', 'No social advertising', ARRAY['used_car','showroom'], 1500, 2500, 'monthly', 7, 'Meta ads with car inventory = lowest cost per lead in UAE market.', 'social_presence_score < 50'),
('Technology', 'CRM System Setup', 'Losing leads due to no tracking', ARRAY['used_car','showroom','broker','rental'], 2500, 5000, 'one_time', 8, 'How many leads called last month and you never followed up? CRM fixes this.', 'estimated_monthly_leads > 50'),
('Technology', 'WhatsApp Business Automation', 'Slow WhatsApp response losing leads', ARRAY['used_car','broker','rental'], 500, 1200, 'one_time', 9, '73% of UAE car buyers prefer WhatsApp. Auto-reply ensures zero leads are lost.', 'whatsapp_button = false'),
('Branding', 'Brand Identity Package', 'No consistent branding', ARRAY['used_car','showroom'], 2000, 4000, 'one_time', 6, 'Trust = sales. Branded dealers sell at higher margins and attract better buyers.', 'branding_score < 4'),
('Reputation', 'Reputation Management', 'Low Google reviews hurting trust', ARRAY['used_car','showroom','workshop'], 800, 1500, 'monthly', 7, 'UAE buyers read reviews before visiting. Under 50 reviews = low trust = lost sales.', 'google_reviews < 50'),
('Technology', 'Inventory Management System', 'No online inventory system', ARRAY['used_car','showroom','rental'], 3000, 6000, 'one_time', 7, 'Buyers want to browse inventory online before visiting. No system = no serious buyers.', 'inventory_online = false');

-- ============================================================
-- SCHEMA COMPLETE
-- ============================================================
