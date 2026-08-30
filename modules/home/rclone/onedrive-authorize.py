#!/usr/bin/env python3
"""Bootstrap the OneDrive rclone remote by running the OAuth flow once.

Unlike every other rclone remote here, OneDrive is NOT managed by
programs.rclone: Microsoft rotates the refresh token on every use, while the
home-manager module rewrites rclone.conf wholesale on each activation. Storing
the token in SOPS would therefore hand back an aging value that breaks at the
first rebuild past its lifetime. So the token lives in its own config file that
rclone owns and nix never touches — see the decision note
`onedrive-token-outside-nix` in the Obsidian vault.

Consequence, and the reason this script exists: a fresh host needs one
interactive browser authorization. Idempotent — exits early if the remote works.
"""

import base64
import hashlib
import http.server
import json
import os
import secrets
import socketserver
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

# Public client ID of the "rclone-backup" Azure app registration. Not a secret:
# it travels in the clear in every authorization request. The app is a public
# client, so it has no usable client secret — PKCE authenticates the exchange.
CLIENT_ID = "28321fbb-d634-4284-a108-0a46f4c6af0d"

CONFIG = os.path.expanduser("~/.config/rclone/onedrive.conf")
RCLONE = "/etc/profiles/per-user/yoshintame/bin/rclone"
REDIRECT = "http://localhost:53682/"
PORT = 53682
SCOPE = "Files.ReadWrite.All offline_access User.Read"
AUTHORITY = "https://login.microsoftonline.com/common/oauth2/v2.0"


def already_working() -> bool:
    if not os.path.exists(CONFIG):
        return False
    r = subprocess.run([RCLONE, "--config", CONFIG, "about", "onedrive:"],
                       capture_output=True, text=True)
    return r.returncode == 0


def authorize() -> dict:
    verifier = base64.urlsafe_b64encode(os.urandom(64)).decode().rstrip("=")
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    state = secrets.token_urlsafe(16)

    url = f"{AUTHORITY}/authorize?" + urllib.parse.urlencode({
        "client_id": CLIENT_ID, "response_type": "code", "redirect_uri": REDIRECT,
        "response_mode": "query", "scope": SCOPE, "state": state,
        "code_challenge": challenge, "code_challenge_method": "S256",
        "prompt": "select_account",
    })

    print("Open this URL and sign in with the personal Microsoft account:\n")
    print(url, "\n")
    subprocess.run(["open", url], capture_output=True)

    captured: dict = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "code" in q and not captured:
                captured["code"] = q["code"][0]
                captured["state"] = q.get("state", [""])[0]
                body = b"<h2>Authorized. You can close this tab.</h2>"
            elif "error" in q:
                captured["error"] = q.get("error_description", q["error"])[0]
                body = b"<h2>Authorization failed, see terminal.</h2>"
            else:
                body = b"<h2>Waiting...</h2>"
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as srv:
        srv.timeout = 300
        while not captured:
            srv.handle_request()

    if "error" in captured:
        sys.exit(f"authorization failed: {captured['error']}")
    if captured.get("state") != state:
        sys.exit("state mismatch — aborting")

    payload = {
        "client_id": CLIENT_ID, "grant_type": "authorization_code",
        "code": captured["code"], "redirect_uri": REDIRECT,
        "code_verifier": verifier, "scope": SCOPE,
    }
    try:
        r = urllib.request.urlopen(urllib.request.Request(
            f"{AUTHORITY}/token",
            data=urllib.parse.urlencode(payload).encode()), timeout=60)
        return json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"token exchange failed: {e.read().decode()[:500]}")


def write_config(token: dict) -> None:
    import datetime
    expiry = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(
        seconds=int(token.get("expires_in", 3600)))).isoformat()
    blob = json.dumps({
        "access_token": token["access_token"],
        "token_type": token.get("token_type", "Bearer"),
        "refresh_token": token["refresh_token"],
        "expiry": expiry,
    }, separators=(",", ":"))

    drive = json.loads(urllib.request.urlopen(urllib.request.Request(
        "https://graph.microsoft.com/v1.0/me/drive",
        headers={"Authorization": "Bearer " + token["access_token"]}), timeout=30).read())

    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    with open(CONFIG, "w") as f:
        f.write("[onedrive]\n")
        f.write("type = onedrive\n")
        f.write(f"client_id = {CLIENT_ID}\n")
        f.write(f"drive_id = {drive['id']}\n")
        f.write(f"drive_type = {drive.get('driveType', 'personal')}\n")
        f.write(f"token = {blob}\n")
    os.chmod(CONFIG, 0o600)
    print(f"wrote {CONFIG}")


def main() -> None:
    if already_working():
        print(f"{CONFIG} already authorized and reachable — nothing to do.")
        return
    write_config(authorize())
    r = subprocess.run([RCLONE, "--config", CONFIG, "about", "onedrive:"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"remote still unreachable:\n{r.stderr}")
    print(r.stdout)


if __name__ == "__main__":
    main()
