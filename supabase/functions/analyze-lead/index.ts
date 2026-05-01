import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ANTHROPIC_KEY = Deno.env.get('ANTHROPIC_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { lead_id } = await req.json()

    if (!lead_id) {
      return new Response(JSON.stringify({ error: 'lead_id is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

    const { data: lead, error: leadError } = await supabase
      .from('leads')
      .select('*, website_audits(*), social_audits(*), competitors(*)')
      .eq('id', lead_id)
      .single()

    if (leadError || !lead) {
      return new Response(JSON.stringify({ error: 'Lead not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { data: services } = await supabase
      .from('services')
      .select('service_name, solves_problem, trigger_condition')
      .eq('is_active', true)

    const servicesList = services?.map((s: { service_name: string }) => s.service_name).join(', ') || ''

    const prompt = `You are an AI Growth Consultant specializing in UAE automotive businesses.

Analyze this UAE car dealership and return ONLY valid JSON (no markdown, no explanation):

BUSINESS PROFILE:
Name: ${lead.business_name}
Type: ${lead.dealer_type}
Emirate: ${lead.emirate}, ${lead.city}
Years Active: ${lead.years_in_market || 'Unknown'}
Cars in Stock: ${lead.cars_in_stock || 'Unknown'}

DIGITAL PRESENCE:
Website: ${lead.website || 'NONE'}
Website Status: ${lead.website_status}
Website Score: ${lead.website_score}/100
SEO Score: ${lead.seo_score}/100
Mobile Score: ${lead.mobile_score}/100
Google Rating: ${lead.google_rating || 'N/A'} (${lead.google_reviews || 0} reviews)
Instagram Followers: ${lead.instagram_followers || 0}
Instagram Last Post: ${lead.instagram_last_post || 'Unknown'}
Instagram Engagement: ${lead.instagram_engagement || 0}%
Facebook Followers: ${lead.facebook_followers || 0}
Primary Email: ${lead.email_primary || 'None found'}
Gmail Found: ${lead.gmail_found || 'No'}

COMPETITOR DATA:
Competitor 1: ${lead.competitor_1_name || 'Unknown'} - Website Score: ${lead.competitor_1_score || 'Unknown'}, Reviews: ${lead.competitor_1_reviews || 'Unknown'}
Competitor 2: ${lead.competitor_2_name || 'N/A'}
Competitor 3: ${lead.competitor_3_name || 'N/A'}

SERVICES WE OFFER: ${servicesList}

Return this EXACT JSON structure:
{
  "why_behind": "2-3 specific sentences explaining their exact digital weaknesses vs competitors",
  "growth_opportunities": "Top 3 specific growth opportunities with estimated impact",
  "pitch_summary": "3-line agent pitch script starting with their biggest pain point",
  "recommended_services": ["service1", "service2", "service3"],
  "priority_package": "Single most important service to pitch first",
  "ai_analysis": "Full 4-sentence consultant-style business intelligence paragraph",
  "lead_score": 0,
  "close_probability": 0,
  "urgency_score": 0,
  "digital_weakness_score": 0,
  "estimated_budget_tier": "low|medium|high|enterprise",
  "email_reachability_score": 0
}`

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': ANTHROPIC_KEY,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 1500,
        messages: [{ role: 'user', content: prompt }]
      })
    })

    const aiResponse = await response.json()

    if (!aiResponse.content || !aiResponse.content[0]) {
      return new Response(JSON.stringify({ error: 'AI response empty', details: aiResponse }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const rawText = aiResponse.content[0].text

    let analysis
    try {
      const cleaned = rawText.replace(/```json|```/g, '').trim()
      analysis = JSON.parse(cleaned)
    } catch {
      return new Response(JSON.stringify({ error: 'AI parse failed', raw: rawText }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { error: updateError } = await supabase
      .from('leads')
      .update({
        why_behind: analysis.why_behind,
        growth_opportunities: analysis.growth_opportunities,
        pitch_summary: analysis.pitch_summary,
        recommended_services: analysis.recommended_services,
        priority_package: analysis.priority_package,
        ai_analysis: analysis.ai_analysis,
        lead_score: analysis.lead_score,
        close_probability: analysis.close_probability,
        urgency_score: analysis.urgency_score,
        digital_weakness_score: analysis.digital_weakness_score,
        estimated_budget_tier: analysis.estimated_budget_tier,
        email_reachability_score: analysis.email_reachability_score,
        ai_analyzed_at: new Date().toISOString(),
        status: analysis.lead_score >= 70 ? 'ready_to_pitch' : 'scraped'
      })
      .eq('id', lead_id)

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ success: true, analysis }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: 'Internal error', details: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
