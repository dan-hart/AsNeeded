"""Render brand artwork with the repository's exact font outlines and icon layers."""
from pathlib import Path
import json
import shutil
import subprocess
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
YELLOW = '#F1D89C'
INK = '#252A2D'
MUTED = '#555040'
FONTS = {weight: TTFont(ROOT / f'AsNeeded/Resources/Fonts/AtkinsonHyperlegible-{weight}.ttf')
         for weight in ['Regular', 'Bold']}


def text(value, x, baseline, size, weight='Regular', fill=INK):
    font = FONTS[weight]
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = size / font['head'].unitsPerEm
    cursor = 0
    parts = []
    for char in value:
        name = cmap[ord(char)]
        pen = SVGPathPen(glyphs)
        glyphs[name].draw(pen)
        parts.append(f'<path transform="translate({cursor} 0)" d="{pen.getCommands()}"/>')
        cursor += font['hmtx'][name][0]
    return (f'<g aria-label="{value}" fill="{fill}" transform="translate({x} {baseline}) scale({scale} {-scale})">'
            + ''.join(parts) + '</g>')


def icon_layer(name, x, y):
    source = ROOT / 'AsNeeded/AppIcon.icon/Assets' / name
    local_name = 'blue-pill.png' if name.startswith('AN-Bottom') else 'pink-pill.png'
    (OUT / 'assets').mkdir(exist_ok=True)
    shutil.copyfile(source, OUT / 'assets' / local_name)
    return f'<image x="{x}" y="{y}" width="1024" height="1024" href="assets/{local_name}"/>'


def pills(x, y, width):
    # Reproduce Icon Composer's layer translations, with the transparent canvas inset removed.
    return (f'<g transform="translate({x} {y}) scale({width / 822})"><g transform="translate(-95 -181)">'
            + icon_layer('AN-Bottom-Pill-export-02 2.png', -38, -85)
            + icon_layer('an-top-pill-export-02.png', 8, 158) + '</g></g>')


def decoration(height):
    return f'''
    <g fill="none" stroke="{INK}" stroke-width="3" opacity="0.065">
      <circle cx="3500" cy="{height * .13}" r="610"/>
      <circle cx="3500" cy="{height * .13}" r="700"/>
      <path d="M3500 {height * .13 - 440}v440l260 150" stroke-linecap="round"/>
      <rect x="-530" y="{height - 580}" width="1100" height="470" rx="235" transform="rotate(-28 20 {height - 345})"/>
    </g>'''


def render(name, width, height, content):
    source = OUT / f'{name}.svg'
    source.write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
      <title>As Needed — {name.replace('-', ' ')}</title>
      <desc>App-icon yellow background. Exact Atkinson Hyperlegible outlines. Original medication icon artwork.</desc>
      <rect width="{width}" height="{height}" fill="{YELLOW}"/>
      {decoration(height)}{content}
    </svg>''')
    intermediate = OUT / f'.{name}-rgba.png'
    subprocess.run(['rsvg-convert', str(source), '-o', str(intermediate)], check=True)
    subprocess.run(['magick', str(intermediate), '-alpha', 'off', '-colorspace', 'sRGB',
                    f'PNG24:{OUT / (name + ".png")}'], check=True)
    intermediate.unlink()


render('header', 3840, 1646,
       pills(1130, 580, 550)
       + text('As Needed', 1785, 805, 185, 'Bold')
       + text('A little less clock math.', 1790, 925, 67))

render('search-results', 3840, 2560,
       text('As Needed', 950, 900, 88, 'Bold')
       + text('Keep track.', 945, 1130, 183, 'Bold')
       + text('Carry on.', 945, 1325, 183, 'Bold')
       + text('As-needed medication tracking.', 954, 1490, 64, fill=MUTED)
       + pills(2210, 1010, 770))

(OUT / 'manifest.json').write_text(json.dumps({
    'background': YELLOW,
    'backgroundSource': 'AsNeeded/AppIcon.icon/icon.json fill.solid',
    'font': 'Atkinson Hyperlegible Regular and Bold, bundled TTF outlines; no font substitution',
    'assets': [{'file': 'header.png', 'width': 3840, 'height': 1646},
               {'file': 'search-results.png', 'width': 3840, 'height': 2560}],
    'format': 'Opaque RGB PNG, sRGB',
    'specification': 'https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications',
    'sourceArtwork': 'Original AppIcon.icon layers, referenced from assets/ without modifying source files',
    'status': 'Local draft; not uploaded or submitted'
}, indent=2) + '\n')
