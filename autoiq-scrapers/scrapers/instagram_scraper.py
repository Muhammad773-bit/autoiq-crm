import requests
from loguru import logger
import re
from datetime import datetime

from config.settings import USER_AGENT


def scrape_instagram_public(handle: str) -> dict:
    if not handle:
        return {'ig_score': 0}

    handle = handle.strip().lstrip('@')
    url = f"https://www.instagram.com/{handle}/"

    result = {
        'ig_handle': handle,
        'ig_url': url,
        'ig_followers': 0,
        'ig_following': 0,
        'ig_posts': 0,
        'ig_avg_likes': 0,
        'ig_avg_comments': 0,
        'ig_engagement_rate': 0,
        'ig_posting_freq': 'unknown',
        'ig_last_post': None,
        'ig_bio_quality': 0,
        'ig_whatsapp_bio': False,
        'ig_website_bio': False,
        'ig_email_bio': None,
        'ig_reels_usage': False,
        'ig_story_highlights': 0,
        'ig_paid_ads': False,
        'ig_branding_score': 0,
        'ig_score': 0,
    }

    headers = {
        'User-Agent': USER_AGENT,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
    }

    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code != 200:
            logger.warning(f"Instagram returned {response.status_code} for @{handle}")
            return result

        content = response.text

        # Extract follower/following/post counts from meta tags or JSON
        follower_match = re.search(r'"edge_followed_by":\{"count":(\d+)\}', content)
        following_match = re.search(r'"edge_follow":\{"count":(\d+)\}', content)
        posts_match = re.search(r'"edge_owner_to_timeline_media":\{"count":(\d+)', content)

        if follower_match:
            result['ig_followers'] = int(follower_match.group(1))
        if following_match:
            result['ig_following'] = int(following_match.group(1))
        if posts_match:
            result['ig_posts'] = int(posts_match.group(1))

        # Fallback: extract from meta description
        if result['ig_followers'] == 0:
            meta_match = re.search(
                r'(\d[\d,.]*[KMkm]?)\s*Followers',
                content,
                re.IGNORECASE
            )
            if meta_match:
                result['ig_followers'] = _parse_count(meta_match.group(1))

        # Bio analysis
        bio_match = re.search(r'"biography":"([^"]*)"', content)
        if bio_match:
            bio = bio_match.group(1)
            result['ig_whatsapp_bio'] = 'whatsapp' in bio.lower() or 'wa.me' in bio.lower()
            result['ig_website_bio'] = 'http' in bio.lower() or 'www' in bio.lower()

            email_match = re.search(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', bio)
            if email_match:
                result['ig_email_bio'] = email_match.group(0)

            bio_score = 0
            if len(bio) > 20:
                bio_score += 20
            if result['ig_whatsapp_bio']:
                bio_score += 20
            if result['ig_website_bio']:
                bio_score += 20
            if result['ig_email_bio']:
                bio_score += 20
            if any(kw in bio.lower() for kw in ['car', 'auto', 'motor', 'vehicle', 'dealer']):
                bio_score += 20
            result['ig_bio_quality'] = min(bio_score, 100)

        # Calculate IG score
        ig_score = 0
        if result['ig_followers'] > 5000:
            ig_score += 25
        elif result['ig_followers'] > 1000:
            ig_score += 15
        elif result['ig_followers'] > 0:
            ig_score += 5

        if result['ig_posts'] > 100:
            ig_score += 20
        elif result['ig_posts'] > 30:
            ig_score += 10

        ig_score += min(result['ig_bio_quality'] // 5, 20)

        if result['ig_followers'] > 0 and result['ig_avg_likes'] > 0:
            engagement = (result['ig_avg_likes'] / result['ig_followers']) * 100
            result['ig_engagement_rate'] = round(engagement, 2)
            if engagement > 3:
                ig_score += 20
            elif engagement > 1:
                ig_score += 10

        result['ig_score'] = min(ig_score, 100)

        # Branding score
        branding = 0
        if result['ig_bio_quality'] > 50:
            branding += 30
        if result['ig_posts'] > 50:
            branding += 30
        if result['ig_followers'] > 2000:
            branding += 20
        if result['ig_website_bio']:
            branding += 20
        result['ig_branding_score'] = min(branding, 100)

    except Exception as e:
        logger.error(f"Instagram scrape failed for @{handle}: {e}")

    return result


def _parse_count(text: str) -> int:
    text = text.strip().replace(',', '')
    multiplier = 1
    if text.upper().endswith('K'):
        multiplier = 1000
        text = text[:-1]
    elif text.upper().endswith('M'):
        multiplier = 1_000_000
        text = text[:-1]
    try:
        return int(float(text) * multiplier)
    except ValueError:
        return 0
