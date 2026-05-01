import re
import dns.resolver
from loguru import logger
from typing import Optional


def extract_emails_from_text(text: str) -> list[str]:
    pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    emails = list(set(re.findall(pattern, text)))
    excluded = ['example', 'youremail', 'wixpress', 'sentry', 'webpack', 'localhost']
    return [e for e in emails if not any(ex in e.lower() for ex in excluded)]


def classify_emails(emails: list[str]) -> dict:
    result = {
        'info_email': None,
        'sales_email': None,
        'admin_email': None,
        'owner_gmail': None,
        'best_outreach_email': None,
        'gmail_found': [],
        'domain_emails_found': [],
    }

    gmail_list = [e for e in emails if 'gmail.com' in e.lower()]
    domain_list = [e for e in emails if 'gmail.com' not in e.lower()]

    result['gmail_found'] = gmail_list
    result['domain_emails_found'] = domain_list

    for email in emails:
        local = email.split('@')[0].lower()
        if 'info' in local:
            result['info_email'] = email
        elif 'sales' in local or 'sell' in local:
            result['sales_email'] = email
        elif 'admin' in local or 'office' in local:
            result['admin_email'] = email

    if gmail_list:
        result['owner_gmail'] = gmail_list[0]

    if result['sales_email']:
        result['best_outreach_email'] = result['sales_email']
    elif result['info_email']:
        result['best_outreach_email'] = result['info_email']
    elif domain_list:
        result['best_outreach_email'] = domain_list[0]
    elif gmail_list:
        result['best_outreach_email'] = gmail_list[0]

    return result


def check_google_workspace(domain: str) -> bool:
    try:
        answers = dns.resolver.resolve(domain, 'MX')
        for rdata in answers:
            mx = str(rdata.exchange).lower()
            if 'google' in mx or 'gmail' in mx:
                return True
    except Exception:
        pass
    return False


def check_microsoft_365(domain: str) -> bool:
    try:
        answers = dns.resolver.resolve(domain, 'MX')
        for rdata in answers:
            mx = str(rdata.exchange).lower()
            if 'outlook' in mx or 'microsoft' in mx:
                return True
    except Exception:
        pass
    return False


def calculate_reachability_score(email_data: dict) -> int:
    score = 0
    if email_data.get('best_outreach_email'):
        score += 30
    if email_data.get('gmail_found'):
        score += 20
    if email_data.get('domain_emails_found'):
        score += 20
    if email_data.get('info_email'):
        score += 10
    if email_data.get('sales_email'):
        score += 10
    if email_data.get('google_workspace'):
        score += 10
    return min(score, 100)


def discover_emails_for_lead(lead_id: int, sources: dict, supabase_client) -> bool:
    all_emails = []

    for source_name, emails in sources.items():
        if emails:
            all_emails.extend(emails if isinstance(emails, list) else [emails])

    all_emails = list(set(all_emails))
    classified = classify_emails(all_emails)

    domain = None
    for email in classified.get('domain_emails_found', []):
        domain = email.split('@')[1]
        break

    google_ws = check_google_workspace(domain) if domain else False
    ms_365 = check_microsoft_365(domain) if domain else False

    reachability = calculate_reachability_score({
        **classified,
        'google_workspace': google_ws
    })

    try:
        supabase_client.table('email_intelligence').insert({
            'lead_id': lead_id,
            'emails_found': all_emails,
            'gmail_found': classified['gmail_found'],
            'domain_emails_found': classified['domain_emails_found'],
            'info_email': classified['info_email'],
            'sales_email': classified['sales_email'],
            'admin_email': classified['admin_email'],
            'owner_gmail': classified['owner_gmail'],
            'best_outreach_email': classified['best_outreach_email'],
            'google_workspace': google_ws,
            'microsoft_365': ms_365,
            'source_website': sources.get('website', []),
            'source_instagram': sources.get('instagram', []),
            'source_facebook': sources.get('facebook', []),
            'source_google': sources.get('google', []),
            'reachability_score': reachability,
        }).execute()

        supabase_client.table('leads').update({
            'email_primary': classified['best_outreach_email'],
            'gmail_found': classified['owner_gmail'],
            'preferred_outreach_email': classified['best_outreach_email'],
            'email_reachability_score': reachability,
            'email_verified': True if classified['best_outreach_email'] else False,
        }).eq('id', lead_id).execute()

        return True
    except Exception as e:
        logger.error(f"Failed to save email intel for lead {lead_id}: {e}")
        return False
