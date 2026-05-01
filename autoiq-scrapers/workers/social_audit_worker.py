import time
from loguru import logger

from scrapers.instagram_scraper import scrape_instagram_public
from scrapers.facebook_scraper import scrape_facebook_public
from config.settings import BATCH_SIZE, RATE_LIMIT_SECONDS


def run_social_audits(supabase_client):
    logger.info("Starting social audit batch")

    result = (
        supabase_client.table('leads')
        .select('id, instagram_handle, facebook_url, business_name')
        .eq('scraping_status', 'complete')
        .limit(BATCH_SIZE)
        .execute()
    )

    leads = result.data
    if not leads:
        logger.info("No leads for social audit")
        return 0

    # Filter leads that don't have social audits yet
    lead_ids = [l['id'] for l in leads]
    existing = (
        supabase_client.table('social_audits')
        .select('lead_id')
        .in_('lead_id', lead_ids)
        .execute()
    )
    existing_ids = {r['lead_id'] for r in existing.data}
    leads = [l for l in leads if l['id'] not in existing_ids]

    success_count = 0
    for lead in leads:
        try:
            ig_data = {}
            fb_data = {}

            if lead.get('instagram_handle'):
                ig_data = scrape_instagram_public(lead['instagram_handle'])
                time.sleep(RATE_LIMIT_SECONDS)

            if lead.get('facebook_url'):
                fb_data = scrape_facebook_public(lead['facebook_url'])
                time.sleep(RATE_LIMIT_SECONDS)

            overall_score = 0
            if ig_data.get('ig_score', 0) > 0 or fb_data.get('fb_score', 0) > 0:
                ig_weight = ig_data.get('ig_score', 0) * 0.6
                fb_weight = fb_data.get('fb_score', 0) * 0.4
                overall_score = int(ig_weight + fb_weight)

            audit_record = {
                'lead_id': lead['id'],
                **ig_data,
                **fb_data,
                'overall_social_score': overall_score,
            }

            supabase_client.table('social_audits').insert(audit_record).execute()

            # Update lead social scores
            update_data = {
                'social_presence_score': overall_score,
            }
            if ig_data.get('ig_score'):
                update_data['instagram_score'] = ig_data['ig_score']
                update_data['instagram_followers'] = ig_data.get('ig_followers', 0)
                update_data['instagram_engagement'] = ig_data.get('ig_engagement_rate', 0)
            if fb_data.get('fb_score'):
                update_data['facebook_score'] = fb_data['fb_score']
                update_data['facebook_followers'] = fb_data.get('fb_followers', 0)

            supabase_client.table('leads').update(update_data).eq('id', lead['id']).execute()

            success_count += 1
            logger.success(f"Social audit done: lead {lead['id']} ({lead.get('business_name', '')})")

        except Exception as e:
            logger.error(f"Social audit failed for lead {lead['id']}: {e}")

    logger.info(f"Social audit batch complete: {success_count}/{len(leads)} successful")
    return success_count
