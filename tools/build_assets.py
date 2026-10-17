#!/usr/bin/env python3
"""Reproducible asset build: 4K antialiased strategy map and worldwide ICAO airports.

Existing 361 airports always retain their names, rankings and identifiers.
OurAirports / datasets airport-codes supplies additional real airports.
Both generated files are bundled into the exported Godot PCK. No runtime web requests.
"""
from __future__ import annotations
import csv, io, json, math, re, urllib.request
from collections import defaultdict
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
SOURCE = "https://raw.githubusercontent.com/datasets/airport-codes/main/data/airport-codes.csv"
MAX_ADDITIONAL = 2300
WIDTH, HEIGHT = 4096, 2048

ALIASES = {
    "US": "USA", "GB": "UK", "RU": "Russia", "KR": "South Korea",
    "KP": "North Korea", "TR": "Turkey", "CZ": "Czechia",
    "VN": "Vietnam", "TW": "Taiwan", "BO": "Bolivia",
    "TZ": "Tanzania", "VA": "Vatican City", "IR": "Iran",
}
COUNTRIES = {
    "SE":"Sweden","NO":"Norway","DK":"Denmark","FI":"Finland",
    "IS":"Iceland","DE":"Germany","FR":"France","IT":"Italy",
    "ES":"Spain","PT":"Portugal","NL":"Netherlands","BE":"Belgium",
    "CH":"Switzerland","AT":"Austria","PL":"Poland","IE":"Ireland",
    "GR":"Greece","GB":"UK","US":"USA","CA":"Canada",
    "MX":"Mexico","BR":"Brazil","AR":"Argentina","CL":"Chile",
    "AU":"Australia","NZ":"New Zealand","JP":"Japan","CN":"China",
    "IN":"India","SG":"Singapore","MY":"Malaysia","ID":"Indonesia",
    "TH":"Thailand","VN":"Vietnam","PH":"Philippines","KR":"South Korea",
    "AE":"United Arab Emirates","SA":"Saudi Arabia","QA":"Qatar",
    "ZA":"South Africa","EG":"Egypt","TR":"Turkey","RU":"Russia",
    "UA":"Ukraine","CZ":"Czechia","HU":"Hungary","RO":"Romania",
    "BG":"Bulgaria","HR":"Croatia","SI":"Slovenia","SK":"Slovakia",
    "RS":"Serbia","IL":"Israel","CY":"Cyprus","MA":"Morocco",
    "DZ":"Algeria","KE":"Kenya","NG":"Nigeria","PK":"Pakistan",
    "BD":"Bangladesh","LK":"Sri Lanka","TW":"Taiwan","HK":"Hong Kong",
    "CO":"Colombia","PE":"Peru","UY":"Uruguay","UY":"Uruguay",
}
def fetch(url: str) -> str:
    request = urllib.request.Request(url,headers={"User-Agent":"Aeroroute-Asset-Generator/1.0"})
    with urllib.request.urlopen(request,timeout=90) as resp:
        return resp.read().decode("utf-8-sig")

def build_airports() -> None:
    original = json.loads((DATA/"airports.json").read_text(encoding="utf-8"))
    known_icao = {a["icao"] for a in original}
    known_iata = {a["iata"] for a in original if a.get("iata")}
    raw = fetch(SOURCE)
    reader = csv.DictReader(io.StringIO(raw))
    pool = defaultdict(list)
    for a in reader:
        typ = a.get("type","")
        scheduled = a.get("scheduled_service","").lower() == "yes"
        if typ not in ("large_airport","medium_airport","small_airport"):
            continue
        # airport-codes removes scheduled_service; IATA + medium/large types are
        # useful candidates, although traffic class remains a game estimate.
        if typ == "small_airport" and not (a.get("iata_code") or "").strip():
            continue
        if typ == "medium_airport" and not ((a.get("iata_code") or "").strip() or scheduled):
            continue
        icao = (a.get("gps_code") or a.get("ident") or "").strip().upper()
        iata = (a.get("iata_code") or "").strip().upper()
        if not re.fullmatch(r"[A-Z]{4}",icao) or icao in known_icao:
            continue
        if iata and (not re.fullmatch("[A-Z]{3}",iata) or iata in known_iata):
            iata = ""
        try:
            if a.get("coordinates"):
                pair = a["coordinates"].split(",")
                lat,lon = float(pair[0]),float(pair[1])
            else:
                lat,lon=float(a["latitude_deg"]),float(a["longitude_deg"])
        except (TypeError,ValueError):
            continue
        if not (-86<=lat<=86 and -180<=lon<=180):
            continue
        country=(a.get("iso_country") or "").upper()
        if not re.fullmatch("[A-Z]{2}",country):
            continue
        # Transparent, game-level proxy; not passenger statistics.
        rank=6 if typ=="large_airport" else (3 if typ=="medium_airport" and "International" in (a.get("name") or "") else 2 if typ=="medium_airport" else 1)
        record={"icao":icao,"iata":iata,"name":(a.get("name") or icao).strip()[:72],
            "lat":round(lat,5),"lon":round(lon,5),
            "country":COUNTRIES.get(country,ALIASES.get(country,country)),"rank":rank}
        # Largest hubs, then scheduled mediums, then scheduled small airports.
        score=(300 if typ=="large_airport" else 110 if typ=="medium_airport" else 35)+(35 if scheduled else 0)
        pool[country].append((score,record))
    for records in pool.values():
        records.sort(key=lambda t:(-t[0],t[1]["icao"]))
    # All major intercontinental hubs first; then geographic diversity by country.
    chosen=[]; used=set(known_icao); used_iata=set(known_iata)
    def append(rec):
        if rec["icao"] in used or (rec["iata"] and rec["iata"] in used_iata):
            return False
        chosen.append(rec);used.add(rec["icao"])
        if rec["iata"]: used_iata.add(rec["iata"])
        return True
    large=[]
    for code,items in pool.items():
        for score,record in items:
            if score>=300: large.append(record)
    for rec in sorted(large,key=lambda r:r["icao"]):
        if len(chosen)>=MAX_ADDITIONAL: break
        append(rec)
    # Round-robin across countries avoids only concentrating in a few countries.
    groups={k:[r for _,r in v if r["icao"] not in used] for k,v in pool.items()}
    countries=sorted(groups,key=lambda k:(-len(groups[k]),k))
    for _ in range(120):
        if len(chosen)>=MAX_ADDITIONAL:break
        progressed=False
        for country in countries:
            if len(chosen)>=MAX_ADDITIONAL:break
            while groups[country]:
                rec=groups[country].pop(0)
                if append(rec):
                    progressed=True
                    break
        if not progressed:break
    # Preserve original data as the authoritative game baseline.
    if len(chosen)<1100:
        raise RuntimeError(f"Insufficient valid ICAO airports imported: {len(chosen)}")
    target=DATA/"airports_extra.json"
    target.write_text(json.dumps(chosen,ensure_ascii=False,separators=(',',':')),encoding="utf-8")
    print(f"AIRPORTS: {len(original)} original + {len(chosen)} additional = {len(original)+len(chosen)} actual ICAO airports; {len({a['country'] for a in chosen})} country values",flush=True)

def build_world_texture() -> None:
    rings=json.loads((DATA/"land.json").read_text())
    # Antialias coastlines at 1.5x resolution, then downsample once offline.
    w,h=WIDTH*3//2,HEIGHT*3//2
    mask=Image.new("L",(w,h),0)
    draw=ImageDraw.Draw(mask)
    for ring in rings:
        if len(ring)<3:continue
        pts=[(int(round((float(x)+180.0)*w/360.0)),
              int(round((90.0-float(y))*h/180.0))) for x,y in ring]
        # Prevent a polygon from covering the planet due to the antimeridian.
        span=max(x for x,y in pts)-min(x for x,y in pts)
        if span>=w*0.87:
            for shifted in (-w,0,w):
                centered=[(x+shifted,y) for x,y in pts]
                draw.polygon(centered,fill=255)
        else:
            draw.polygon(pts,fill=255)
    mask=mask.resize((WIDTH,HEIGHT),Image.Resampling.LANCZOS)
    # Premultiplied alpha artwork; transparent seas are drawn by Godot.
    land=Image.new("RGB",(WIDTH,HEIGHT),(229,235,222))
    land.putalpha(mask)
    # Coastline shading gives the continents clear silhouettes without 3-D terrain.
    # Keep texture at 4K but PNG-compress to limit iPhone download and VRAM.
    target=DATA/"world_land.png"
    land.save(target,optimize=True,compress_level=8)
    print(f"MAP: 4096x2048 antialiased continent texture, {target.stat().st_size//1024} KiB",flush=True)

if __name__=="__main__":
    build_airports()
    build_world_texture()
