from supabase import create_client, Client
from loguru import logger
from config.settings import SUPABASE_URL, SUPABASE_KEY


def get_supabase_client() -> Client:
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set in environment")
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def get_pending_leads(client: Client, limit: int = 20):
    result = (
        client.table('leads')
        .select('id, website, business_name, instagram_handle, facebook_url')
        .eq('scraping_status', 'pending')
        .limit(limit)
        .execute()
    )
    return result.data


def update_lead(client: Client, lead_id: int, data: dict):
    try:
        client.table('leads').update(data).eq('id', lead_id).execute()
        return True
    except Exception as e:
        logger.error(f"Failed to update lead {lead_id}: {e}")
        return False


def insert_website_audit(client: Client, lead_id: int, audit_data: dict):
    try:
        client.table('website_audits').insert({
            'lead_id': lead_id,
            **audit_data
        }).execute()
        return True
    except Exception as e:
        logger.error(f"Failed to insert website audit for lead {lead_id}: {e}")
        return False


def insert_social_audit(client: Client, lead_id: int, audit_data: dict):
    try:
        client.table('social_audits').insert({
            'lead_id': lead_id,
            **audit_data
        }).execute()
        return True
    except Exception as e:
        logger.error(f"Failed to insert social audit for lead {lead_id}: {e}")
        return False


def insert_email_intelligence(client: Client, lead_id: int, email_data: dict):
    try:
        client.table('email_intelligence').insert({
            'lead_id': lead_id,
            **email_data
        }).execute()
        return True
    except Exception as e:
        logger.error(f"Failed to insert email intel for lead {lead_id}: {e}")
        return False
