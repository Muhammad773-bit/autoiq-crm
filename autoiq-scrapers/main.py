import schedule
import time
from loguru import logger
from supabase import create_client

from config.settings import SUPABASE_URL, SUPABASE_KEY
from workers.website_audit_worker import run_website_audits
from workers.social_audit_worker import run_social_audits
from workers.email_discovery_worker import run_email_discovery

logger.add("logs/autoiq_scraper.log", rotation="10 MB", retention="30 days")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


def run_all():
    logger.info("=" * 50)
    logger.info("Running full scraping pipeline")
    logger.info("=" * 50)

    try:
        website_count = run_website_audits(supabase)
        logger.info(f"Website audits completed: {website_count}")
    except Exception as e:
        logger.error(f"Website audit batch failed: {e}")

    try:
        social_count = run_social_audits(supabase)
        logger.info(f"Social audits completed: {social_count}")
    except Exception as e:
        logger.error(f"Social audit batch failed: {e}")

    try:
        email_count = run_email_discovery(supabase)
        logger.info(f"Email discoveries completed: {email_count}")
    except Exception as e:
        logger.error(f"Email discovery batch failed: {e}")

    logger.info("Full pipeline run complete")


# Schedule jobs
schedule.every().day.at("03:00").do(run_all)
schedule.every().hour.do(lambda: run_website_audits(supabase))
schedule.every(2).hours.do(lambda: run_social_audits(supabase))
schedule.every(3).hours.do(lambda: run_email_discovery(supabase))

if __name__ == '__main__':
    logger.info("AutoIQ Scraping Worker started")
    logger.info(f"Supabase URL: {SUPABASE_URL[:30]}...")

    # Run immediately on start
    run_all()

    logger.info("Entering scheduled loop...")
    while True:
        schedule.run_pending()
        time.sleep(60)
