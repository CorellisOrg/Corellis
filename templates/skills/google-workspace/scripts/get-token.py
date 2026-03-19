#!/usr/bin/env python3
"""
Get Google API access token using Service Account + Domain-wide Delegation.
Usage: python3 get-token.py [user@company.com]
  - Without argument: uses SA's own identity
  - With argument: impersonates that user (requires Domain-wide Delegation)
Outputs just the token string to stdout.
"""
import sys
from google.oauth2 import service_account
from google.auth.transport.requests import Request

import pathlib
_SKILL_DIR = pathlib.Path(__file__).resolve().parent.parent
SA_FILE = str(_SKILL_DIR / "secrets" / "google-sa.json")
SCOPES = [
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/documents",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/presentations",
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/indexing",
]

subject = sys.argv[1] if len(sys.argv) > 1 else None
creds = service_account.Credentials.from_service_account_file(
    SA_FILE, scopes=SCOPES, subject=subject
)
creds.refresh(Request())
print(creds.token)
