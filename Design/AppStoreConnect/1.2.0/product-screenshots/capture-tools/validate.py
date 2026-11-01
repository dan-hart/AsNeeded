"""Validate marketing exports and the direction of the fictional usage data."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
from collections import defaultdict
import hashlib
import json
from PIL import Image
from frame_duo import frame_duo, SCREENS

ROOT = Path(__file__).resolve().parent.parent
SIZES = {'iphone': (1206, 2622), 'ipad': (2064, 2752),
         'duo-inner': (2853, 2007), 'duo-outer': (1398, 2034), 'watch': (416, 496)}
manifest = json.loads((ROOT/'manifest.json').read_text())
assert len(manifest['images']) == 20
for family, size in SIZES.items():
    paths = list((ROOT/family).glob('*.png'))
    assert len(paths) == 4, family
    for path in paths:
        image = Image.open(path)
        assert image.mode == 'RGB' and image.size == size, path
        assert image.getpixel((0, 0)) == (241, 216, 156), path
for record in manifest['images']:
    path = ROOT/record['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path

provenance = json.loads((ROOT/'capture-tools/duo-frames/provenance.json').read_text())
for name, record in provenance['assets'].items():
    path = ROOT/'capture-tools/duo-frames'/name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path
for family, geometry in SCREENS.items():
    for path in (ROOT/'raw'/family).glob('*.png'):
        raw = Image.open(path).convert('RGBA')
        framed = frame_duo(path, family)
        x, y = raw.width//2, raw.height//2
        dx, dy = geometry['origin']
        assert framed.getpixel((x+dx, y+dy)) == raw.getpixel((x, y)), path
        assert framed.getpixel((0, 0))[3] == 0, path

fixture = json.loads((ROOT/'sample-data.json').read_text())
assert len(fixture['medications']) == 3
assert len({m['displayColorHex'] for m in fixture['medications']}) == 3
zone = ZoneInfo('America/Chicago')
today = datetime.fromisoformat(fixture['exportDate'].replace('Z', '+00:00')).astimezone(zone).date()
daily = defaultdict(lambda: defaultdict(float))
for event in fixture['events']:
    date = datetime.fromisoformat(event['date'].replace('Z', '+00:00')).astimezone(zone).date()
    age = (today-date).days
    daily[event['medication']['nickname']][age] += event['dose']['amount']
trends = {}
for name in ['Headache Help', 'Breathe Easy']:
    older = sum(daily[name][age] for age in range(24, 31))/7
    recent = sum(daily[name][age] for age in range(1, 8))/7
    trends[name] = {'oldestWeekDailyMean': round(older, 2), 'latestWeekDailyMean': round(recent, 2)}
assert trends['Headache Help']['latestWeekDailyMean'] < trends['Headache Help']['oldestWeekDailyMean']/2
assert trends['Breathe Easy']['latestWeekDailyMean'] > trends['Breathe Easy']['oldestWeekDailyMean']*2
report = {'imagesValidated': 20, 'format': 'Opaque RGB PNG', 'background': '#F1D89C',
          'duoFrames': 'Pinned assets and untouched central UI pixels verified',
          'fictionalEvents': len(fixture['events']), 'trends': trends}
(ROOT/'validation.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
