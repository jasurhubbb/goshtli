"""Register (or clear) the Telegram webhook so Telegram POSTs updates to our backend.

Run once after deploy (or whenever the public URL / secret changes):

    python manage.py set_telegram_webhook --base-url https://goshtli-production1.up.railway.app
    python manage.py set_telegram_webhook --delete      # stop receiving updates

The webhook URL is <base-url>/api/v1/telegram/webhook/ and Telegram is told to send the
X-Telegram-Bot-Api-Secret-Token header = settings.TELEGRAM_WEBHOOK_SECRET on every call.
"""
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.telegram_auth import telegram_api


class Command(BaseCommand):
    help = "Register or delete the Telegram bot webhook."

    def add_arguments(self, parser):
        parser.add_argument("--base-url", default="",
                            help="Public https base, e.g. https://goshtli-production1.up.railway.app")
        parser.add_argument("--delete", action="store_true", help="Delete the webhook instead of setting it.")

    def handle(self, *_, **opts):
        if not settings.TELEGRAM_BOT_TOKEN:
            raise CommandError("TELEGRAM_BOT_TOKEN is not set in the environment.")

        if opts["delete"]:
            res = telegram_api.delete_webhook()
            self.stdout.write(self.style.SUCCESS(f"deleteWebhook → {res}"))
            return

        if not settings.TELEGRAM_WEBHOOK_SECRET:
            raise CommandError("TELEGRAM_WEBHOOK_SECRET is not set — refusing to register an unsecured webhook.")
        base = (opts["base_url"] or "").rstrip("/")
        if not base.startswith("https://"):
            raise CommandError("--base-url must be an https:// URL (Telegram requires HTTPS webhooks).")
        url = f"{base}/api/v1/telegram/webhook/"
        res = telegram_api.set_webhook(url, settings.TELEGRAM_WEBHOOK_SECRET)
        if res is None:
            raise CommandError("setWebhook failed — check the token + logs.")
        self.stdout.write(self.style.SUCCESS(f"Webhook set → {url}\n{res}"))
