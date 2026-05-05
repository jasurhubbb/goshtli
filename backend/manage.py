#!/usr/bin/env python
# Django CLI entrypoint — defaults to development settings; override with DJANGO_SETTINGS_MODULE
import os, sys


def main():
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")
    try: from django.core.management import execute_from_command_line
    except ImportError as exc: raise ImportError("Django not installed or venv not active") from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__": main()
