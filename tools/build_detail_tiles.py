#!/usr/bin/env python3
"""Build a curated playable airport network and detailed map tiles for iPhone.

Source coastline: Natural Earth 1:10m public-domain GIS (downloaded at build).
Tiles are generated once in CI, not fetched from the network while playing.
"""
from __future__ import annotations
import json, math, urllib.request
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"data"
TILE_FOLDER=DATA/"map_tiles"
TILE_SIZE=1280
SUPERSAMPLE=1536
DEGREES=20
COLUMNS=18
ROWS=9
SEA=(22,57,75)
LAND=(81,111,112)
SOURCE="https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson"
IMPORTANT={"ESSA","ESSP","ESGJ","ESGG","ESMS","ESSV","EKCH","EGLL","KJFK","OMDB","WSSS","EDDF","LFPG","KLAX","RJTT","YSSY"}

def km(a,b):
    r=math.pi/180
    la1,la2=float(a["lat"])*r,float(b["lat"])*r
    dlat=la2-la1
    dlon=(float(b["lon"])-float(a["lon"]))*r
    v=math.sin(dlat*.5)**2+math.cos(la1)*math.cos(la2)*math.sin(dlon*.5)**2
    return 12742*math.asin(math.sqrt(max(0,min(1,v))))

def curate():
    baseline=json.loads((DATA/"airports.json").read_text(encoding="utf-8"))
    extras=json.loads((DATA/"airports_extra.json").read_text(encoding="utf-8"))
    canonical={a["icao"]:a for a in baseline}
    for a in extras:
        canonical.setdefault(a["icao"],a)
    candidates=[a for a in canonical.values() if
        a["icao"] in IMPORTANT or int(a["rank"])>=3 or
        (int(a["rank"])>=2 and bool(a.get("iata")))]
    original={a["icao"] for a in baseline}
    candidates.sort(key=lambda a:(
        a["icao"] not in IMPORTANT,
        -int(a["rank"]),
        a["icao"] not in original,
        not bool(a.get("iata")),
        a["icao"]))
    picked=[]
    for airport in candidates:
        if len(picked)>=1350:break
        is_priority=airport["icao"] in IMPORTANT
        # Retain carefully chosen local airports but remove minor same-city duplicates.
        threshold=36.0 if int(airport["rank"])>=6 else (48.0 if int(airport["rank"])>=4 else 67.0)
        if not is_priority and any(km(airport,selected)<threshold for selected in picked):
            continue
        picked.append(airport)
    selected=sorted(a["icao"] for a in picked)
    if len(selected)<350 or len(selected)>1350:
        raise RuntimeError(f"Curated commercial network size unexpected: {len(selected)}")
    if not IMPORTANT.issubset(set(selected)):
        raise RuntimeError("Missing hand-picked airports essential for existing play")
    (DATA/"airports_featured.json").write_text(json.dumps(selected,separators=(",",":")),encoding="utf-8")
    print(f"CURATED: {len(selected)} playable commercial airports; {len(canonical)} original/backward-compatible records preserved.",flush=True)

def unwrap_ring(coords):
    if not coords:return []
    result=[]
    prev=float(coords[0][0])
    for x,y in coords:
        lon=float(x)
        while lon-prev>180:lon-=360
        while lon-prev< -180:lon+=360
        result.append((lon,float(y)))
        prev=lon
    return result

def polies():
    request=urllib.request.Request(SOURCE,headers={"User-Agent":"Aeroroute-Godot-Game/0.9.9"})
    with urllib.request.urlopen(request,timeout=100) as response:
        land=json.loads(response.read())
    geo=[]
    for feat in land["features"]:
        geometry=feat.get("geometry") or {}
        geom_type=geometry.get("type")
        coordinates=geometry.get("coordinates") or []
        polygons=[coordinates] if geom_type=="Polygon" else coordinates if geom_type=="MultiPolygon" else []
        for polygon in polygons:
            if not polygon:continue
            rings=[unwrap_ring(ring) for ring in polygon if len(ring)>=3]
            if not rings:continue
            outline=rings[0]
            minx=min(p[0] for p in outline)
            maxx=max(p[0] for p in outline)
            miny=min(p[1] for p in outline)
            maxy=max(p[1] for p in outline)
            if minx<-400 or maxx>550:continue
            geo.append((minx,maxx,miny,maxy,rings))
    print(f"COAST: read {len(geo)} detailed Natural Earth polygons.",flush=True)
    return geo

def create_tiles():
    polygons=polies()
    TILE_FOLDER.mkdir(exist_ok=True)
    last=0
    for ty in range(ROWS):
        north=90-ty*DEGREES
        south=north-DEGREES
        for tx in range(COLUMNS):
            west=-180+tx*DEGREES
            east=west+DEGREES
            mask=Image.new("L",(SUPERSAMPLE,SUPERSAMPLE),0)
            draw=ImageDraw.Draw(mask)
            for minx,maxx,miny,maxy,rings in polygons:
                if maxy<south or miny>north:continue
                for shift in (-360,0,360):
                    if maxx+shift<west or minx+shift>east:continue
                    for n,ring in enumerate(rings):
                        # The geometry may extend outside tile bounds; PIL clips.
                        points=[(round(((x+shift)-west)*SUPERSAMPLE/DEGREES),
                                 round((north-y)*SUPERSAMPLE/DEGREES)) for x,y in ring]
                        draw.polygon(points,fill=255 if n==0 else 0)
            if mask.getbbox() is None:
                image=Image.new("RGB",(TILE_SIZE,TILE_SIZE),SEA)
            else:
                alpha=mask.resize((TILE_SIZE,TILE_SIZE),Image.Resampling.LANCZOS)
                image=Image.new("RGB",(TILE_SIZE,TILE_SIZE),SEA)
                image.paste(LAND,(0,0,TILE_SIZE,TILE_SIZE),alpha)
            image.save(TILE_FOLDER/f"{tx:02d}_{ty:02d}.png",optimize=True,compress_level=6)
            last+=1
        print(f"TILES: generated {last}/{ROWS*COLUMNS} geographic tiles.",flush=True)
    if last!=162:raise RuntimeError("Unexpected tile count")
    print("MAP-DETAIL: 162 high-resolution tile images built for close zoom.",flush=True)

if __name__=="__main__":
    curate()
    create_tiles()
