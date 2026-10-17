#!/usr/bin/env python3
"""Generate a simplified FIR dataset for Aeroroute, from non-authoritative global GIS data."""
import json,urllib.request
from pathlib import Path
URL="https://raw.githubusercontent.com/Transport-Environment/atm_and_contrail_avoidance/main/data/worldfirs.json"
def simplify(p,tol=.08):
    if len(p)<4:return p
    def rec(a):
        if len(a)<3:return a
        x0,y0=a[0];x1,y1=a[-1];dx=x1-x0;dy=y1-y0;den=dx*dx+dy*dy
        best=0;idx=0
        for i,(x,y) in enumerate(a[1:-1],1):
            u=max(0,min(1,((x-x0)*dx+(y-y0)*dy)/den)) if den else 0
            d=((x-x0-u*dx)**2+(y-y0-u*dy)**2)**.5
            if d>best:best=d;idx=i
        return rec(a[:idx+1])[:-1]+rec(a[idx:]) if best>tol else [a[0],a[-1]]
    result=rec(p)
    return result if len(result)>=3 else p[:3]
def main():
    with urllib.request.urlopen(URL,timeout=40) as r:top=json.load(r)
    scale=top['transform']['scale'];trans=top['transform']['translate']
    arcs=[]
    for arc in top['arcs']:
        x=y=0;line=[]
        for dx,dy in arc:
            x+=dx;y+=dy;line.append((x*scale[0]+trans[0],y*scale[1]+trans[1]))
        arcs.append(line)
    def join(seq):
        pts=[]
        for k in seq:
            line=arcs[k] if k>=0 else list(reversed(arcs[~k]))
            pts+=line if not pts else line[1:]
        return pts
    regions=[]
    for feature in top['objects']['data']['geometries']:
        p=feature['properties']
        if p.get('type')!='FIR':continue
        polys=feature['arcs'] if feature['type']=='MultiPolygon' else [feature['arcs']]
        rings=[]
        for polygon in polys:
            if not polygon:continue
            points=join(polygon[0])
            if len(points)>=3:rings.append([[round(x,4),round(y,4)] for x,y in simplify(points)])
        if not rings:continue
        allpoints=[pt for ring in rings for pt in ring]
        lon=sum(pt[0] for pt in allpoints)/len(allpoints)
        lat=sum(pt[1] for pt in allpoints)/len(allpoints)
        regions.append({'code':p.get('designator') or 'FIR','name':p.get('name') or 'FIR','lon':round(lon,3),'lat':round(lat,3),'rings':rings})
    target=Path(__file__).resolve().parents[1]/'data/fir_regions.json'
    target.write_text(json.dumps({'source':URL,'regions':regions},ensure_ascii=False,separators=(',',':')))
    assert len(regions)>200, f'FIR coverage unexpectedly low: {len(regions)}'
    print(f'Generated {len(regions)} worldwide FIR features, {target.stat().st_size} bytes')
if __name__=='__main__':main()
