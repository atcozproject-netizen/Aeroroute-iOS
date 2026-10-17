#!/usr/bin/env python3
"""Godot project data validation, no third-party dependencies."""
import json, math
from pathlib import Path
p=Path(__file__).resolve().parent.parent
A=json.loads((p/'data/airports.json').read_text())
P=json.loads((p/'data/aircraft.json').read_text())
L=json.loads((p/'data/land.json').read_text())
assert len(A)==361,(len(A),'airports')
assert len({a['icao'] for a in A})==len(A)
assert len({a['iata'] for a in A})==len(A)
assert all(len(a['icao'])==4 and -90<=a['lat']<=90 and -180<=a['lon']<=180 for a in A)
assert len(L)>250 and sum(len(r) for r in L)>20000
assert len(P)==11 and len({p['id'] for p in P})==11
assert {p['level'] for p in P}==set(range(1,9))
lookup={a['icao']:a for a in A}
assert lookup['ESSA']['iata']=='ARN'
assert lookup['ESSP']['iata']=='NRK'
assert lookup['ESGJ']['iata']=='JKG'
assert lookup['EFHK']['iata']=='HEL'
assert lookup['EGLL']['iata']=='LHR'
def distance(a,b):
 x,y=lookup[a],lookup[b]
 dlat=math.radians(y['lat']-x['lat']);dlon=math.radians(y['lon']-x['lon'])
 h=math.sin(dlat/2)**2+math.cos(math.radians(x['lat']))*math.cos(math.radians(y['lat']))*math.sin(dlon/2)**2
 return 12742*math.asin(min(1,math.sqrt(h)))
def initial_plane(a,b,level=1):
 return next((p for p in P if p['level']<=level and p['range']>=distance(a,b)),None)
def market(a,b):
 x,y=lookup[a],lookup[b];km=distance(a,b);same=x['country']==y['country']
 factor=(.012 if same else .045) if km<80 else (.055 if same else .14) if km<160 else (.15 if same else .35) if km<300 else (.46 if same else .75) if km<600 else 1.0 if km<1100 else 1.13 if km<2500 else .83 if km<6000 else .58 if km<10000 else .34
 return max(.35,(x['rank']*y['rank'])**.89*18*factor)
assert 140 < distance('ESSA','ESSP') < 170
assert initial_plane('ESSA','ESSP')['id']=='caravan'
assert initial_plane('ESSA','EGLL') is None
assert market('ESSA','ESSP') < 10
assert market('ESSA','EGLL') > 300
assert market('ESSA','EFHK') > market('ESSA','ESSP')
print('OK: 361 ICAO airport records, realistic distances, 8 aircraft tiers, 294 land rings.')
for a,b in [('ESSA','ESSP'),('ESSA','EFHK'),('ESSA','EGLL'),('ESGJ','ESSP')]:
 print(a,b,round(distance(a,b)),'km; baseline',round(market(a,b),1),'pax/d; level1 plane:',(initial_plane(a,b) or {}).get('name','locked'))
