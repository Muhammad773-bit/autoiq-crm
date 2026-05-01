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
    const { lead_id, email_step = 1, agent_name = 'Your Name' } = await req.json()

    if (!lead_id) {
      return new Response(JSON.stringify({ error: 'lead_id is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

    const { data: lead, error: leadError } = await supabase
      .from('leads')
      .select('*')
      .eq('id', lead_id)
      .single()

    if (leadError || !lead) {
      return new Response(JSON.stringify({ error: 'Lead not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const stepContextMap: Record<number, string> = {
      1: 'cold outreach — first ever contact',
      2: 'friendly follow-up — no response to first email yet',
      3: 'value-add follow-up — share insight about their competitor',
      4: 'final attempt — be direct and create urgency'
    }
    const stepContext = stepContextMap[email_step] || 'follow-up'

    const prompt = `Write a cold outreach email for a UAE digital agency contacting a car dealership.

Context: ${stepContext}
Business: ${lead.business_name}
Emirate: ${lead.emirate}
Problem: ${lead.why_behind}
Best Service to Pitch: ${lead.priority_package}
Competitor they are losing to: ${lead.competitor_1_name || 'top competitors'}
Our Agent: ${agent_name}

Rules:
- Subject must mention their city or business name — make it feel personal
- Reference their SPECIFIC digital weakness, not generic
- Under 120 words for body
- UAE business culture: respectful, professional, not pushy
- End with: "Would a quick 15-minute call this week work for you?"
- Sign off as: ${agent_name}, Digital Growth Consultant

Return ONLY this JSON (no markdown):
{
  "subject": "...",
  "body": "..."
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
        max_tokens: 600,
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

    let email
    try {
      email = JSON.parse(rawText.replace(/```json|```/g, '').trim())
    } catch {
      return new Response(JSON.stringify({ error: 'Parse failed', raw: rawText }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ success: true, email }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: 'Internal error', details: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
