"""Add every App Store Connect team member who has accepted their invite to the
internal "Dyspatch Team" TestFlight group of both apps. Safe to run any time:
people already in a group are skipped. Pending invites are only listed."""
import json, os, sys, time, urllib.error, urllib.parse, urllib.request
import jwt  # PyJWT

API = "https://api.appstoreconnect.apple.com/v1"
GROUPS = {
    "Dyspatch (customer)": "5821630e-edc5-420e-9089-75ec2d6259bb",
    "Dyspatch Rider": "fcbd93ec-2f6c-441b-b2d9-48d40a787548",
}
ONLY = {e.strip().lower() for e in os.environ.get("ONLY_EMAILS", "").split(",") if e.strip()}

key = open(sys.argv[1]).read()
token = jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": int(time.time()),
                    "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"},
                   key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]})
H = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def call(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url if url.startswith("http") else API + url, data=data, method=method, headers=H)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw.decode(errors="replace")}


def get_all(url):
    out = []
    while url:
        st, js = call("GET", url)
        if st != 200:
            raise SystemExit(f"GET {url} failed {st}: {js}")
        out += js.get("data", [])
        url = js.get("links", {}).get("next")
    return out


users = get_all("/users?limit=200")
print(f"Team members who have accepted: {len(users)}")
for u in users:
    a = u["attributes"]
    print(f"  - {a.get('username')}  ({', '.join(a.get('roles', []))})")

pending = get_all("/userInvitations?limit=200")
if pending:
    print("Still pending (have not accepted the Apple invite yet):")
    for p in pending:
        print(f"  - {p['attributes'].get('email')}")

for label, gid in GROUPS.items():
    current = {t["attributes"].get("email", "").lower() for t in get_all(f"/betaGroups/{gid}/betaTesters?limit=200")}
    print(f"\n{label}: {len(current)} tester(s) in Dyspatch Team")
    for u in users:
        a = u["attributes"]
        email = (a.get("username") or a.get("email") or "").lower()
        if not email or (ONLY and email not in ONLY):
            continue
        if email in current:
            print(f"  = {email} already in group")
            continue
        body = {"data": {"type": "betaTesters",
                         "attributes": {"email": email, "firstName": a.get("firstName") or "Tester",
                                        "lastName": a.get("lastName") or "Dyspatch"},
                         "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}}}}
        st, js = call("POST", "/betaTesters", body)
        if st in (200, 201):
            print(f"  + {email} added")
            continue
        # Tester already exists elsewhere: link the existing record to this group.
        found = get_all(f"/betaTesters?filter[email]={urllib.parse.quote(email)}&limit=5") if st == 409 else []
        if found:
            st2, js2 = call("POST", f"/betaGroups/{gid}/relationships/betaTesters",
                            {"data": [{"type": "betaTesters", "id": found[0]['id']}]})
            print(f"  + {email} added (existing tester)" if st2 in (200, 204) else f"  ! {email} failed {st2}: {js2}")
        else:
            print(f"  ! {email} failed {st}: {json.dumps(js)[:400]}")


# ---- Check access + resend TestFlight invites for the selected people ----
APPS = {"Dyspatch (customer)": "6834452009", "Dyspatch Rider": "6834452261"}
if ONLY:
    print("\nAccess check / resend:")
    for u in users:
        email = (u["attributes"].get("username") or "").lower()
        if email not in ONLY:
            continue
        a = u["attributes"]
        vis = [x["id"] for x in get_all(f"/users/{u['id']}/visibleApps?limit=50")] if not a.get("allAppsVisible") else ["ALL"]
        print(f"  {email}: roles={a.get('roles')} visibleApps={vis}")
        missing = [i for i in APPS.values() if vis != ["ALL"] and i not in vis]
        if missing:
            st, js = call("POST", f"/users/{u['id']}/relationships/visibleApps",
                          {"data": [{"type": "apps", "id": i} for i in missing]})
            print(f"    gave access to apps {missing}: {st}")
        bt = get_all(f"/betaTesters?filter[email]={urllib.parse.quote(email)}&limit=5")
        for t in bt:
            print(f"    tester state={t['attributes'].get('state')} inviteType={t['attributes'].get('inviteType')}")
        for label, app_id in APPS.items():
            gid = GROUPS[label]
            builds = get_all(f"/betaGroups/{gid}/builds?limit=5")
            print(f"    {label}: group has {len(builds)} build(s)")
            if bt:
                st, js = call("POST", "/betaTesterInvitations", {"data": {"type": "betaTesterInvitations", "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                    "betaTester": {"data": {"type": "betaTesters", "id": bt[0]["id"]}}}}})
                print(f"    resent {label} invite: {st} {'' if st in (200, 201) else json.dumps(js)[:300]}")
