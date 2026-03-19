#!/usr/bin/env python3
"""
Google OAuth helper for headless servers.
Usage:
  python3 google-oauth.py auth           → prints auth URL for user to visit
  python3 google-oauth.py exchange <code> → exchanges code for refresh token, saves it
  python3 google-oauth.py token           → prints access token (auto-refreshes)
  
Credentials are stored in workspace: ~/.openclaw/workspace/.google-oauth/
"""
import json, sys, os
from urllib.request import urlopen, Request
from urllib.parse import urlencode, urlparse, parse_qs

import pathlib
_SKILL_DIR = pathlib.Path(__file__).resolve().parent.parent
CLIENT_SECRET_FILE = str(_SKILL_DIR / "secrets" / "google-oauth-client.json")
SCOPES = [
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/documents",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/analytics.readonly",
    "https://www.googleapis.com/auth/indexing",
]

def load_client():
    with open(CLIENT_SECRET_FILE) as f:
        data = json.load(f)
    installed = data.get("installed", data.get("web", {}))
    return installed["client_id"], installed["client_secret"]

def get_creds_dir():
    # Store in workspace so tokens persist across sessions
    workspace = os.environ.get("OPENCLAW_WORKSPACE", os.path.expanduser("~/.openclaw/workspace"))
    d = os.path.join(workspace, ".google-oauth")
    os.makedirs(d, exist_ok=True)
    return d

def auth_url():
    client_id, _ = load_client()
    params = {
        "client_id": client_id,
        "redirect_uri": "http://localhost",
        "response_type": "code",
        "scope": " ".join(SCOPES),
        "access_type": "offline",
        "prompt": "consent",
    }
    url = f"https://accounts.google.com/o/oauth2/auth?{urlencode(params)}"
    print(url)

def exchange_code(code):
    client_id, client_secret = load_client()
    data = urlencode({
        "code": code,
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uri": "http://localhost",
        "grant_type": "authorization_code",
    }).encode()
    req = Request("https://oauth2.googleapis.com/token", data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    resp = json.loads(urlopen(req).read())
    
    # Save tokens
    creds_file = os.path.join(get_creds_dir(), "tokens.json")
    with open(creds_file, "w") as f:
        json.dump(resp, f, indent=2)
    os.chmod(creds_file, 0o600)
    
    print(f"✅ Tokens saved to {creds_file}")
    if "refresh_token" in resp:
        print(f"Refresh token: {resp['refresh_token'][:20]}...")
    print(f"Access token expires in: {resp.get('expires_in', '?')}s")

def get_token():
    creds_file = os.path.join(get_creds_dir(), "tokens.json")
    with open(creds_file) as f:
        tokens = json.load(f)
    
    # Try refresh
    client_id, client_secret = load_client()
    data = urlencode({
        "refresh_token": tokens["refresh_token"],
        "client_id": client_id,
        "client_secret": client_secret,
        "grant_type": "refresh_token",
    }).encode()
    req = Request("https://oauth2.googleapis.com/token", data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    resp = json.loads(urlopen(req).read())
    print(resp["access_token"])

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "auth":
        auth_url()
    elif cmd == "exchange" and len(sys.argv) > 2:
        exchange_code(sys.argv[2])
    elif cmd == "token":
        get_token()
    else:
        print("Usage: google-oauth.py [auth|exchange <code>|token]")
