"""Render brand artwork with the repository's exact font outlines and icon layers."""
from pathlib import Path
import argparse
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


def render(name, width, height, content, decorated=True):
    source = OUT / f'{name}.svg'
    source.write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
      <title>As Needed — {name.replace('-', ' ')}</title>
      <desc>App-icon yellow background. Exact Atkinson Hyperlegible outlines. Original medication icon artwork.</desc>
      <rect width="{width}" height="{height}" fill="{YELLOW}"/>
      {decoration(height) if decorated else ''}{content}
    </svg>''')
    intermediate = OUT / f'.{name}-rgba.png'
    subprocess.run(['rsvg-convert', str(source), '-o', str(intermediate)], check=True)
    subprocess.run(['magick', str(intermediate), '-alpha', 'off', '-colorspace', 'sRGB',
                    f'PNG24:{OUT / (name + ".png")}'], check=True)
    intermediate.unlink()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--only', choices=['header', 'search-results', 'all'], default='all')
selection = parser.parse_args().only

if selection in ['header', 'all']:
    # Apple's PSD Art Safe Area: (1097, 493), 1646 x 661.
    # The original pill layers and exact font ink occupy x=1109..2732,
    # centered vertically, retaining 12 px of horizontal breathing room.
    render('header', 3840, 1646,
           pills(1109, 598, 574)
           + text('As Needed', 1747, 886, 193, 'Bold'), decorated=False)

if selection in ['search-results', 'all']:
    render('search-results', 3840, 2560,
       text('As Needed', 950, 900, 88, 'Bold')
       + text('Keep track.', 945, 1130, 183, 'Bold')
       + text('Carry on.', 945, 1325, 183, 'Bold')
       + text('As-needed medication tracking.', 954, 1490, 64, fill=MUTED)
       + pills(2210, 1010, 770))

manifest_path = OUT / 'manifest.json'
existing = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
manifest_path.write_text(json.dumps({
    **existing,
    'background': YELLOW,
    'backgroundSource': 'AsNeeded/AppIcon.icon/icon.json fill.solid',
    'font': 'Atkinson Hyperlegible Regular and Bold, bundled TTF outlines; no font substitution',
    'assets': [{'file': 'header.png', 'width': 3840, 'height': 1646},
               {'file': 'search-results.png', 'width': 3840, 'height': 2560}],
    'format': 'Opaque RGB PNG, sRGB',
    'specification': 'https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications',
    'sourceArtwork': 'Original AppIcon.icon layers, referenced from assets/ without modifying source files',
    'status': f'Locally regenerated {selection}; verify upload status before publication',
    'headerLayout': {'subtitle': False, 'safeArea': {'x': 1097, 'y': 493, 'width': 1646, 'height': 661},
                     'safeAreaSource': 'Apple creative_assets-product_page_header_template-static.psd, Art Safe Area layer',
                     'brandingBounds': {'left': 1109, 'top': 598, 'right': 2732, 'bottom': 1049},
                     'pillWidth': 574, 'wordmarkFontSize': 193, 'gap': 64}
}, indent=2) + '\n')
