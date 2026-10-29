"""Frame real simulator captures. Run from the repository root with Koubou 0.20.0."""
from pathlib import Path
import json
import subprocess
import hashlib
import os
from PIL import Image, ImageDraw, ImageFont

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

# No invented Duo hardware: retain each real display's full aspect ratio in a simple inset.
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
        scale = min(w*.92/source.width, h*.78/source.height)
        screen = source.resize((round(source.width*scale), round(source.height*scale)), Image.Resampling.LANCZOS)
        x, y = (w-screen.width)//2, round(h*.19)
        draw.rounded_rectangle((x-5,y-5,x+screen.width+5,y+screen.height+5), radius=24, fill='#252A2D')
        canvas.paste(screen,(x,y))
        canvas.save(OUT/family/(name+'.png'))

watch_copy = ['Keep it close.', 'Know what’s left.', 'Log from your wrist.', 'Keep stock in sight.']
watch_sources = sorted((OUT/'raw/watch').glob('*.png'))
(OUT/'watch').mkdir(exist_ok=True)
for path,title in zip(watch_sources,watch_copy):
    source=Image.open(path).convert('RGB')
    canvas=Image.new('RGB',source.size,YELLOW)
    draw=ImageDraw.Draw(canvas)
    draw.text((208,18),title,font=ImageFont.truetype(str(FONT),27),fill='#252A2D',anchor='mt')
    source.thumbnail((358,427),Image.Resampling.LANCZOS)
    x,y=(416-source.width)//2,60
    mask=Image.new('L',source.size,0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,source.width-1,source.height-1),radius=43,fill=255)
    canvas.paste(source,(x,y),mask)
    canvas.save(OUT/'watch'/path.name)

records=[]
for family in ['iphone','ipad','duo-inner','duo-outer','watch']:
    for path in sorted((OUT/family).glob('*.png')):
        image=Image.open(path).convert('RGB')
        image.save(path)
        records.append({'file':str(path.relative_to(OUT)), 'width':image.width,'height':image.height,
                        'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'manifest.json').write_text(json.dumps({'version':'1.2.0 (321)', 'background':YELLOW,
    'font':'Atkinson Hyperlegible', 'source':'Real simulator UI; fictional records only',
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
