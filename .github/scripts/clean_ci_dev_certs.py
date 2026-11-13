"""Revoke the throwaway Apple *Development* certificates that Xcode cloud
signing creates on each CI run (named "Created via API"). Xcode refuses to
create a new one while an old one exists without its private key on the
fresh runner. Distribution certificates are never touched."""
import json, os, sys, time, urllib.request
import jwt  # PyJWT

key = open(sys.argv[1]).read()
token = jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": int(time.time()),
                    "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"},
                   key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]})
H = {"Authorization": f"Bearer {token}"}

def call(method, url):
    req = urllib.request.Request(url, method=method, headers=H)
    with urllib.request.urlopen(req) as r:
        body = r.read()
        return json.loads(body) if body else {}

url = "https://api.appstoreconnect.apple.com/v1/certificates?limit=200"
certs = call("GET", url)["data"]
n = 0
for c in certs:
    a = c["attributes"]
    if a.get("certificateType") in ("DEVELOPMENT", "IOS_DEVELOPMENT") and a.get("displayName", a.get("name", "")) .startswith("Created via API"):
        call("DELETE", f"https://api.appstoreconnect.apple.com/v1/certificates/{c['id']}")
        n += 1
print(f"Revoked {n} CI development certificate(s); left {len(certs) - n} others untouched.")
