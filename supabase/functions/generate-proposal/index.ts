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
    const { lead_id, agent_id } = await req.json()

    if (!lead_id) {
      return new Response(JSON.stringify({ error: 'lead_id is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

    const { data: lead, error: leadError } = await supabase
      .from('leads')
      .select('*, competitors(*)')
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
      .select('*')
      .in('service_name', lead.recommended_services || [])

    const prompt = `Generate a complete sales proposal for a UAE car dealership.

Business: ${lead.business_name}, ${lead.emirate}
Their Problems: ${lead.why_behind}
Recommended Services: ${(lead.recommended_services || []).join(', ')}
Priority Package: ${lead.priority_package}
Competitor: ${lead.competitor_1_name} (they are winning because: ${lead.competitor_1_why_winning})
AI Analysis: ${lead.ai_analysis}

Available service pricing:
${(services || []).map((s: { service_name: string; price_min_aed: number; price_max_aed: number; pricing_type: string }) =>
  `- ${s.service_name}: AED ${s.price_min_aed}-${s.price_max_aed} (${s.pricing_type})`
).join('\n')}

Return ONLY this JSON:
{
  "executive_summary": "2-paragraph summary of their situation and our solution",
  "problems_identified": ["problem1", "problem2", "problem3"],
  "services_breakdown": [{"service": "name", "price_aed": 0, "type": "one_time|monthly", "benefit": "specific benefit"}],
  "one_time_total": 0,
  "monthly_total": 0,
  "roi_conservative": "description with numbers",
  "roi_realistic": "description with numbers",
  "roi_optimistic": "description with numbers",
  "roadmap_month1": "what we do in month 1",
  "roadmap_month2": "what we do in month 2",
  "roadmap_month3": "expected results by month 3",
  "closing_statement": "1 powerful closing paragraph"
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
        max_tokens: 2000,
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

    let proposal
    try {
      proposal = JSON.parse(aiResponse.content[0].text.replace(/```json|```/g, '').trim())
    } catch {
      return new Response(JSON.stringify({ error: 'Parse failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const proposalRef = `PROP-${lead_id}-${Date.now()}`
    const { data: savedProposal, error: saveError } = await supabase
      .from('proposals')
      .insert({
        lead_id,
        agent_id,
        proposal_ref: proposalRef,
        services_included: lead.recommended_services,
        one_time_total_aed: proposal.one_time_total,
        monthly_total_aed: proposal.monthly_total,
        roi_conservative: proposal.roi_conservative,
        roi_realistic: proposal.roi_realistic,
        roi_optimistic: proposal.roi_optimistic,
        roadmap_month1: proposal.roadmap_month1,
        roadmap_month2: proposal.roadmap_month2,
        roadmap_month3: proposal.roadmap_month3,
        ai_generated_content: proposal
      })
      .select()
      .single()

    if (saveError) {
      return new Response(JSON.stringify({ error: saveError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({
      success: true,
      proposal,
      proposal_id: savedProposal?.id,
      proposal_ref: proposalRef
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: 'Internal error', details: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
