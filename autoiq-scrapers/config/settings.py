import os
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv('SUPABASE_URL', '')
SUPABASE_KEY = os.getenv('SUPABASE_KEY', '')
ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY', '')
APIFY_TOKEN = os.getenv('APIFY_TOKEN', '')

BATCH_SIZE = int(os.getenv('BATCH_SIZE', '20'))
RATE_LIMIT_SECONDS = int(os.getenv('RATE_LIMIT_SECONDS', '1'))

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
