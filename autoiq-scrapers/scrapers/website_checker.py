import requests
from bs4 import BeautifulSoup
from loguru import logger
import re

from config.settings import USER_AGENT


def check_website(url: str) -> dict:
    if not url or url.strip() == '':
        return {
            'website_status': 'none',
            'website_score': 0,
            'seo_score': 0,
            'mobile_score': 0,
            'speed_score': 0,
            'ux_score': 0,
            'https_enabled': False,
            'emails_found': [],
            'gmail_found': None,
            'whatsapp_button': False,
            'contact_form': False,
            'inventory_online': False,
            'cta_count': 0,
        }

    headers = {'User-Agent': USER_AGENT}
    result = {
        'website_status': 'unknown',
        'https_enabled': url.startswith('https'),
        'emails_found': [],
        'gmail_found': None,
        'whatsapp_button': False,
        'contact_form': False,
        'inventory_online': False,
        'cta_count': 0,
    }

    try:
        response = requests.get(url, headers=headers, timeout=10, allow_redirects=True)
        result['website_status'] = 'live' if response.status_code < 400 else 'dead'

        soup = BeautifulSoup(response.text, 'lxml')
        content = response.text.lower()

        # Email extraction
        email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
        emails = list(set(re.findall(email_pattern, response.text)))
        result['emails_found'] = [
            e for e in emails
            if 'example' not in e and 'youremail' not in e and 'wixpress' not in e
        ]

        gmail_emails = [e for e in result['emails_found'] if 'gmail.com' in e]
        result['gmail_found'] = gmail_emails[0] if gmail_emails else None

        # SEO checks
        title = soup.find('title')
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        h1_tags = soup.find_all('h1')
        schema = 'schema.org' in response.text or 'application/ld+json' in response.text
        sitemap = 'sitemap' in content
        robots = soup.find('meta', attrs={'name': 'robots'})

        seo_score = 0
        if title:
            seo_score += 20
        if meta_desc:
            seo_score += 20
        if h1_tags and len(h1_tags) == 1:
            seo_score += 15
        if schema:
            seo_score += 20
        if sitemap:
            seo_score += 10
        if len(response.text) > 5000:
            seo_score += 15
        result['seo_score'] = min(seo_score, 100)

        # UX checks
        result['whatsapp_button'] = 'whatsapp' in content or 'wa.me' in content
        result['contact_form'] = bool(soup.find('form'))
        result['inventory_online'] = (
            'inventory' in content or 'stock' in content or 'for sale' in content
        )

        # CTA buttons
        cta_keywords = ['contact', 'call', 'whatsapp', 'enquire', 'book', 'test drive', 'get quote']
        cta_count = sum(1 for kw in cta_keywords if kw in content)
        result['cta_count'] = cta_count

        # Mobile score (heuristic)
        mobile_score = 0
        if 'viewport' in response.text:
            mobile_score += 40
        if 'responsive' in content or 'mobile' in content:
            mobile_score += 30
        if result['whatsapp_button']:
            mobile_score += 30
        result['mobile_score'] = min(mobile_score, 100)

        # Speed score (heuristic based on page size)
        page_size_kb = len(response.content) / 1024
        if page_size_kb < 200:
            result['speed_score'] = 80
        elif page_size_kb < 500:
            result['speed_score'] = 60
        elif page_size_kb < 1000:
            result['speed_score'] = 40
        else:
            result['speed_score'] = 20

        # UX score
        result['ux_score'] = min(cta_count * 20, 100)

        # Overall score
        overall = (
            result['seo_score'] * 0.3
            + result['mobile_score'] * 0.25
            + result['speed_score'] * 0.2
            + result['ux_score'] * 0.25
        )
        result['website_score'] = int(overall)

        # Additional audit fields
        result['title_tags_pct'] = 100 if title else 0
        result['meta_desc_pct'] = 100 if meta_desc else 0
        result['h1_count'] = len(h1_tags)
        result['h1_multiple'] = len(h1_tags) > 1
        result['schema_markup'] = schema
        result['sitemap_exists'] = sitemap
        result['robots_exists'] = robots is not None
        result['mobile_responsive'] = 'viewport' in response.text
        result['call_button'] = 'tel:' in content
        result['live_chat'] = 'livechat' in content or 'tawk' in content or 'intercom' in content
        result['inquiry_form'] = 'inquiry' in content or 'enquiry' in content
        result['finance_calculator'] = 'calculator' in content or 'emi' in content
        result['test_drive_form'] = 'test drive' in content
        result['price_display'] = 'aed' in content or 'price' in content

    except requests.exceptions.ConnectionError:
        result['website_status'] = 'dead'
        result['website_score'] = 0
        result['seo_score'] = 0
        result['mobile_score'] = 0
        result['speed_score'] = 0
        result['ux_score'] = 0
    except Exception as e:
        logger.error(f"Website check failed for {url}: {e}")
        result['website_status'] = 'unknown'

    return result


def audit_lead_website(lead_id: int, url: str, supabase_client) -> bool:
    audit_data = check_website(url)

    try:
        supabase_client.table('website_audits').insert({
            'lead_id': lead_id,
            'url': url,
            'status': audit_data.get('website_status'),
            'https_enabled': audit_data.get('https_enabled'),
            'overall_score': audit_data.get('website_score'),
            'seo_score': audit_data.get('seo_score'),
            'mobile_score': audit_data.get('mobile_score'),
            'speed_score': audit_data.get('speed_score'),
            'ux_score': audit_data.get('ux_score'),
            'emails_found': audit_data.get('emails_found', []),
            'gmail_found': audit_data.get('gmail_found'),
            'whatsapp_button': audit_data.get('whatsapp_button'),
            'contact_form': audit_data.get('contact_form'),
            'inventory_online': audit_data.get('inventory_online'),
            'cta_count': audit_data.get('cta_count'),
            'mobile_responsive': audit_data.get('mobile_responsive'),
            'call_button': audit_data.get('call_button'),
            'live_chat': audit_data.get('live_chat'),
            'inquiry_form': audit_data.get('inquiry_form'),
            'finance_calculator': audit_data.get('finance_calculator'),
            'test_drive_form': audit_data.get('test_drive_form'),
            'price_display': audit_data.get('price_display'),
            'title_tags_pct': audit_data.get('title_tags_pct'),
            'meta_desc_pct': audit_data.get('meta_desc_pct'),
            'h1_count': audit_data.get('h1_count'),
            'h1_multiple': audit_data.get('h1_multiple'),
            'schema_markup': audit_data.get('schema_markup'),
            'sitemap_exists': audit_data.get('sitemap_exists'),
            'robots_exists': audit_data.get('robots_exists'),
        }).execute()

        supabase_client.table('leads').update({
            'website_status': audit_data['website_status'],
            'website_score': audit_data['website_score'],
            'seo_score': audit_data['seo_score'],
            'mobile_score': audit_data['mobile_score'],
            'speed_score': audit_data['speed_score'],
            'ux_score': audit_data['ux_score'],
            'gmail_found': audit_data['gmail_found'],
            'scraping_status': 'complete',
        }).eq('id', lead_id).execute()

        return True
    except Exception as e:
        logger.error(f"Failed to save audit for lead {lead_id}: {e}")
        return False
