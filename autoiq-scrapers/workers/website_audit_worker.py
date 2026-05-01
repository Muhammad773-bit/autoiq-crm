import time
from loguru import logger

from scrapers.website_checker import audit_lead_website
from config.settings import BATCH_SIZE, RATE_LIMIT_SECONDS


def run_website_audits(supabase_client):
    logger.info("Starting website audit batch")

    result = (
        supabase_client.table('leads')
        .select('id, website')
        .eq('scraping_status', 'pending')
        .not_('website', 'is', 'null')
        .neq('website', '')
        .limit(BATCH_SIZE)
        .execute()
    )

    leads = result.data
    if not leads:
        logger.info("No pending leads for website audit")
        return 0

    success_count = 0
    for lead in leads:
        if lead.get('website'):
            try:
                success = audit_lead_website(lead['id'], lead['website'], supabase_client)
                if success:
                    success_count += 1
                    logger.success(f"Audited: lead {lead['id']} ({lead.get('website', '')})")
                else:
                    logger.warning(f"Audit failed for lead {lead['id']}")
            except Exception as e:
                logger.error(f"Error auditing lead {lead['id']}: {e}")
                supabase_client.table('leads').update({
                    'scraping_status': 'failed',
                }).eq('id', lead['id']).execute()

            time.sleep(RATE_LIMIT_SECONDS)

    logger.info(f"Website audit batch complete: {success_count}/{len(leads)} successful")
    return success_count
