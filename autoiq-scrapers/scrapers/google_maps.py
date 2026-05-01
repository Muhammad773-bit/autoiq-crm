import requests
from loguru import logger

from config.settings import USER_AGENT


def extract_google_maps_data(maps_url: str) -> dict:
    if not maps_url:
        return {'google_maps_exists': False}

    result = {
        'google_maps_exists': True,
        'google_rating': None,
        'google_reviews': 0,
        'gbp_photos_count': 0,
        'gbp_owner_replies': False,
    }

    headers = {
        'User-Agent': USER_AGENT,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
    }

    try:
        response = requests.get(maps_url, headers=headers, timeout=15, allow_redirects=True)
        if response.status_code != 200:
            logger.warning(f"Google Maps returned {response.status_code}")
            return result

        content = response.text

        # Extract rating
        import re
        rating_match = re.search(r'"(\d\.\d)" stars', content)
        if not rating_match:
            rating_match = re.search(r'(\d\.\d)\s*/\s*5', content)
        if rating_match:
            result['google_rating'] = float(rating_match.group(1))

        # Extract review count
        review_match = re.search(r'(\d[\d,]*)\s*review', content, re.IGNORECASE)
        if review_match:
            result['google_reviews'] = int(review_match.group(1).replace(',', ''))

        # Photos count
        photo_match = re.search(r'(\d+)\s*photo', content, re.IGNORECASE)
        if photo_match:
            result['gbp_photos_count'] = int(photo_match.group(1))

        # Owner replies
        result['gbp_owner_replies'] = 'response from the owner' in content.lower()

    except Exception as e:
        logger.error(f"Google Maps extraction failed: {e}")

    return result
