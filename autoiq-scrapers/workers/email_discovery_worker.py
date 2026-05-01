import time
from loguru import logger

from scrapers.email_extractor import discover_emails_for_lead, extract_emails_from_text
from scrapers.website_checker import check_website
from config.settings import BATCH_SIZE, RATE_LIMIT_SECONDS


def run_email_discovery(supabase_client):
    logger.info("Starting email discovery batch")

    result = (
        supabase_client.table('leads')
        .select('id, website, instagram_handle, facebook_url, business_name')
        .eq('scraping_status', 'complete')
        .is_('email_primary', 'null')
        .limit(BATCH_SIZE)
        .execute()
    )

    leads = result.data
    if not leads:
        logger.info("No leads for email discovery")
        return 0

    success_count = 0
    for lead in leads:
        try:
            sources = {
                'website': [],
                'instagram': [],
                'facebook': [],
                'google': [],
            }

            # Extract from website
            if lead.get('website'):
                import requests
                try:
                    resp = requests.get(lead['website'], timeout=10, headers={
                        'User-Agent': 'Mozilla/5.0'
                    })
                    sources['website'] = extract_emails_from_text(resp.text)
                except Exception:
                    pass
                time.sleep(RATE_LIMIT_SECONDS)

            # Check existing social audit data for emails
            social_audit = (
                supabase_client.table('social_audits')
                .select('ig_email_bio, fb_email')
                .eq('lead_id', lead['id'])
                .limit(1)
                .execute()
            )
            if social_audit.data:
                sa = social_audit.data[0]
                if sa.get('ig_email_bio'):
                    sources['instagram'] = [sa['ig_email_bio']]
                if sa.get('fb_email'):
                    sources['facebook'] = [sa['fb_email']]

            # Check website audit for emails
            web_audit = (
                supabase_client.table('website_audits')
                .select('emails_found, gmail_found')
                .eq('lead_id', lead['id'])
                .limit(1)
                .execute()
            )
            if web_audit.data:
                wa = web_audit.data[0]
                if wa.get('emails_found'):
                    sources['website'].extend(wa['emails_found'])
                if wa.get('gmail_found'):
                    sources['website'].append(wa['gmail_found'])

            success = discover_emails_for_lead(lead['id'], sources, supabase_client)
            if success:
                success_count += 1
                logger.success(f"Email discovery done: lead {lead['id']} ({lead.get('business_name', '')})")

        except Exception as e:
            logger.error(f"Email discovery failed for lead {lead['id']}: {e}")

    logger.info(f"Email discovery batch complete: {success_count}/{len(leads)} successful")
    return success_count
