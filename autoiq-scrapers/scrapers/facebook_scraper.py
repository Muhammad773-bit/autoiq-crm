import requests
from bs4 import BeautifulSoup
from loguru import logger
import re

from config.settings import USER_AGENT


def scrape_facebook_public(url: str) -> dict:
    if not url:
        return {'fb_score': 0}

    result = {
        'fb_page_url': url,
        'fb_followers': 0,
        'fb_likes': 0,
        'fb_verified': False,
        'fb_review_score': None,
        'fb_review_count': 0,
        'fb_messenger_response': None,
        'fb_cta_type': None,
        'fb_email': None,
        'fb_posting_freq': 'unknown',
        'fb_last_post': None,
        'fb_video_count': 0,
        'fb_lead_form_ads': False,
        'fb_whatsapp_button': False,
        'fb_branding_score': 0,
        'fb_score': 0,
    }

    headers = {
        'User-Agent': USER_AGENT,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
    }

    try:
        response = requests.get(url, headers=headers, timeout=10, allow_redirects=True)
        if response.status_code != 200:
            logger.warning(f"Facebook returned {response.status_code} for {url}")
            return result

        content = response.text.lower()
        soup = BeautifulSoup(response.text, 'lxml')

        # Extract followers from page content
        follower_match = re.search(r'(\d[\d,.]*)\s*(?:people follow|followers)', content)
        if follower_match:
            result['fb_followers'] = _parse_count(follower_match.group(1))

        likes_match = re.search(r'(\d[\d,.]*)\s*(?:people like|likes)', content)
        if likes_match:
            result['fb_likes'] = _parse_count(likes_match.group(1))

        # Check for verification badge
        result['fb_verified'] = 'verified' in content

        # Email extraction
        email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
        emails = re.findall(email_pattern, response.text)
        clean_emails = [e for e in emails if 'facebook' not in e.lower() and 'fb' not in e.lower()]
        if clean_emails:
            result['fb_email'] = clean_emails[0]

        # WhatsApp check
        result['fb_whatsapp_button'] = 'whatsapp' in content or 'wa.me' in content

        # Score calculation
        fb_score = 0
        if result['fb_followers'] > 5000:
            fb_score += 25
        elif result['fb_followers'] > 1000:
            fb_score += 15
        elif result['fb_followers'] > 0:
            fb_score += 5

        if result['fb_likes'] > 3000:
            fb_score += 20
        elif result['fb_likes'] > 500:
            fb_score += 10

        if result['fb_verified']:
            fb_score += 15
        if result['fb_email']:
            fb_score += 10
        if result['fb_whatsapp_button']:
            fb_score += 10
        if result['fb_review_count'] > 20:
            fb_score += 10

        result['fb_score'] = min(fb_score, 100)

        # Branding score
        branding = 0
        if result['fb_followers'] > 2000:
            branding += 30
        if result['fb_verified']:
            branding += 30
        if result['fb_email']:
            branding += 20
        if result['fb_whatsapp_button']:
            branding += 20
        result['fb_branding_score'] = min(branding, 100)

    except Exception as e:
        logger.error(f"Facebook scrape failed for {url}: {e}")

    return result


def _parse_count(text: str) -> int:
    text = text.strip().replace(',', '')
    try:
        return int(float(text))
    except ValueError:
        return 0
