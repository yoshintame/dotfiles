#!/usr/bin/env python3
import json, sys, urllib.request

API_URL = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json;api-version=6.0-preview.1",
}

def query_api(criteria, page_size=1):
    payload = json.dumps({
        "filters": [{
            "criteria": [
                {"filterType": 8, "value": "Microsoft.VisualStudio.Code"},
                *criteria,
            ],
            "pageNumber": 1,
            "pageSize": page_size,
            "sortBy": 4,
            "sortOrder": 1,
        }],
        "assetTypes": [],
        "flags": 914,
    }).encode()
    req = urllib.request.Request(API_URL, data=payload, headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read())["results"][0]["extensions"]

def fmt_ext(ext):
    name = ext["displayName"]
    eid = ext["publisher"]["publisherName"] + "." + ext["extensionName"]
    updated = ext["lastUpdated"][:10]
    ver = ext["versions"][0]["version"]
    stats = {s["statisticName"]: s["value"] for s in ext.get("statistics", [])}
    installs = int(stats.get("install", 0))
    desc = ext.get("shortDescription", "").replace("|", "/")
    return f"{name} | {eid} | {ver} | {installs} | {updated} | {desc}"

def is_extension_id(s):
    parts = s.split(".")
    return len(parts) == 2 and all(parts)

args = sys.argv[1:]
if not args:
    print("Usage: vscode-marketplace.py <search query | publisher.ext [publisher.ext ...]>", file=sys.stderr)
    sys.exit(1)

print("name | id | version | installs | updated | description")
print("--- | --- | --- | --- | --- | ---")

if all(is_extension_id(a) for a in args):
    for eid in args:
        exts = query_api([{"filterType": 7, "value": eid}])
        if not exts:
            print(f"NOT FOUND | {eid} | - | - | - | -")
        else:
            print(fmt_ext(exts[0]))
else:
    query = " ".join(args)
    exts = query_api([{"filterType": 10, "value": query}], page_size=15)
    if not exts:
        print("No results found.")
    else:
        for ext in exts:
            print(fmt_ext(ext))
