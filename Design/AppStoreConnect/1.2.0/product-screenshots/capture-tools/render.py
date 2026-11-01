"""Frame real simulator captures. Run from the repository root with Koubou 0.20.0."""
from pathlib import Path
import json
import subprocess
import hashlib
import os
from PIL import Image, ImageDraw, ImageFont
from frame_duo import frame_duo

ROOT = Path.cwd()
OUT = ROOT / 'Design/AppStoreConnect/1.2.0/product-screenshots'
FONT = ROOT / 'AsNeeded/Resources/Fonts/AtkinsonHyperlegible-Bold.ttf'
REGULAR = FONT.with_name('AtkinsonHyperlegible-Regular.ttf')
YELLOW = '#F1D89C'
COPY = [
    ('01-medication', 'Your meds. Your way.', 'Colors, icons and names that feel familiar.'),
    ('02-history', 'The details, all together.', 'Doses, notes and how you felt.'),
    ('03-trends', 'See your bigger picture.', 'A little history. A lot more perspective.'),
    ('04-log-dose', 'Log it. Carry on.', 'Quick times. Precise amounts. Less fuss.'),
]

for family, device in [('iphone', 'iphone-17'), ('ipad', 'ipad-pro-13')]:
    (OUT / family).mkdir(exist_ok=True)
    for name, title, subtitle in COPY:
        if os.environ.get('SKIP_FRAMES') and (OUT/family/(name+'.png')).exists():
            continue
        subprocess.run(['asc', 'screenshots', 'frame', '--input', str(OUT/'raw'/family/(name+'.png')),
            '--device', device, '--frame-color', 'black' if family == 'iphone' else 'space-gray',
            '--bg-color', YELLOW, '--title-color', '#252A2D', '--subtitle-color', '#555040',
            '--font', str(FONT), '--title', title, '--subtitle', subtitle,
            '--output-path', str(OUT/family/(name+'.png')), '--output', 'json'], check=True)

# Genuine AppleFramer hardware surrounds the complete native display capture.
for family in ['duo-inner', 'duo-outer']:
    (OUT/family).mkdir(exist_ok=True)
    for name, title, subtitle in COPY:
        source = Image.open(OUT/'raw'/family/(name+'.png')).convert('RGB')
        w, h = source.size
        canvas = Image.new('RGB', (w,h), YELLOW)
        draw = ImageDraw.Draw(canvas)
        size = int(w * .047)
        font = ImageFont.truetype(str(FONT), size)
        while draw.textlength(title, font=font) > w*.90:
            size -= 1
            font = ImageFont.truetype(str(FONT), size)
        draw.text((w/2,h*.055), title, font=font, fill='#252A2D', anchor='mt')
        draw.text((w/2,h*.125), subtitle, font=ImageFont.truetype(str(REGULAR),int(w*.023)), fill='#555040', anchor='mt')
        hardware = frame_duo(OUT/'raw'/family/(name+'.png'), family)
        scale = min(w*.94/hardware.width, h*.78/hardware.height)
        hardware = hardware.resize((round(hardware.width*scale), round(hardware.height*scale)), Image.Resampling.LANCZOS)
        x, y = (w-hardware.width)//2, round(h*.19)
        canvas.paste(hardware,(x,y),hardware)
        canvas.save(OUT/family/(name+'.png'))

watch_copy = ['Keep it close.', 'Know what’s left.', 'Log from your wrist.', 'Keep stock in sight.']
watch_sources = sorted((OUT/'raw/watch').glob('*.png'))
(OUT/'watch').mkdir(exist_ok=True)
for path,title in zip(watch_sources,watch_copy):
    subprocess.run(['asc', 'screenshots', 'frame', '--input', str(path),
        '--device', 'watch-series-11', '--frame-color', 'aluminum-jet-black-sport-band-black',
        '--bg-color', YELLOW, '--title-color', '#252A2D', '--font', str(FONT),
        '--title', title, '--output-path', str(OUT/'watch'/path.name), '--output', 'json'], check=True)

records=[]
for family in ['iphone','ipad','duo-inner','duo-outer','watch']:
    for path in sorted((OUT/family).glob('*.png')):
        image=Image.open(path).convert('RGB')
        image.save(path)
        records.append({'file':str(path.relative_to(OUT)), 'width':image.width,'height':image.height,
                        'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'manifest.json').write_text(json.dumps({'version':'1.2.0 (321)', 'background':YELLOW,
    'font':'Atkinson Hyperlegible',
    'source':'Running app on iPhone/iPad/Duo; unchanged production Watch views in capture harness; fictional records only',
    'frames': {'iphone/iPad/Watch':'Koubou 0.20.0 device assets',
               'Duo':'AppleFramer ad533b08fa6ce995b88f36c68a997d7293736cf7 (MIT)'},
    'demoHistory': {'days':90, 'events':496, 'iPhone/iPadTrend':'decreasing', 'DuoTrend':'increasing'},
    'status':'Local review assets; not uploaded', 'images':records},indent=2)+'\n')

# A compact visual proof sheet, separate from upload assets.
thumb_w, thumb_h = 300, 600
rows=[]
for family in ['iphone','ipad','duo-inner','duo-outer','watch']:
    paths=sorted((OUT/family).glob('*.png'))
    if not paths: continue
    thumbs=[]
    for path in paths:
        im=Image.open(path); im.thumbnail((thumb_w-16,thumb_h-10)); thumbs.append(im)
    row=Image.new('RGB',(thumb_w*4,max(im.height for im in thumbs)+65),'#fffaf0')
    d=ImageDraw.Draw(row)
    d.text((12,10),family,font=ImageFont.truetype(str(FONT),24),fill='#252A2D')
    for index,im in enumerate(thumbs):
        row.paste(im,(index*thumb_w+(thumb_w-im.width)//2,45))
    rows.append(row)
gallery=Image.new('RGB',(1200,sum(r.height for r in rows)),'white')
y=0
for row in rows: gallery.paste(row,(0,y)); y+=row.height
gallery.save(OUT/'preview.jpg',quality=90)
