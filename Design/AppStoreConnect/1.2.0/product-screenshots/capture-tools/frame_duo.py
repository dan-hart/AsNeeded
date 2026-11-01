"""Composite full-resolution Duo captures into bundled AppleFramer hardware.

Requires Pillow, like render.py. Assets, coordinates, and mask semantics come
from AppleFramer; see duo-frames/provenance.json and its MIT license.
"""
from pathlib import Path
import argparse

from PIL import Image, ImageChops, ImageDraw


ASSETS = Path(__file__).resolve().parent / 'duo-frames'
PRODUCT = ASSETS.parent.parent
SCREENS = {
	'duo-inner': {'size': (2853, 2007), 'origin': (120, 120)},
	'duo-outer': {'size': (1398, 2034), 'origin': (88, 80)},
}


def frame_duo(source: Path, family: str) -> Image.Image:
	"""Return transparent framed hardware without resizing or cropping the UI."""
	if family not in SCREENS:
		raise ValueError(f'Unsupported Duo family: {family}')
	geometry = SCREENS[family]
	with Image.open(source) as image:
		screen = image.convert('RGBA')
	if screen.size != geometry['size']:
		raise ValueError(f'{source}: expected {geometry["size"]}, got {screen.size}')
	with Image.open(ASSETS / f'{family}-frame.png') as image:
		hardware = image.convert('RGBA')
	with Image.open(ASSETS / f'{family}-mask.png') as image:
		mask = image.convert('RGB')
	if mask.size != screen.size:
		raise ValueError(f'{family}: mask dimensions do not match screen')

	# Upstream masks hide pixels only when every RGB channel is below 10.
	red, green, blue = mask.split()
	keep = ImageChops.lighter(ImageChops.lighter(red, green), blue)
	keep = keep.point(lambda value: 255 if value >= 10 else 0)
	screen.putalpha(ImageChops.multiply(screen.getchannel('A'), keep))
	layer = Image.new('RGBA', hardware.size)
	layer.paste(screen, geometry['origin'])
	# Upstream corner masks are square blocks and can leave UI outside the
	# curved bezel. Flood-fill the exterior from the genuine hardware alpha;
	# the enclosed display stays intact, including its full native aspect.
	boundary = hardware.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
	ImageDraw.floodfill(boundary, (0, 0), 128)
	inside = boundary.point(lambda value: 0 if value == 128 else 255)
	layer.putalpha(ImageChops.multiply(layer.getchannel('A'), inside))
	# Match upstream destination-out, then source-over hardware composition.
	layer.putalpha(ImageChops.multiply(layer.getchannel('A'),
		ImageChops.invert(hardware.getchannel('A'))))
	return Image.alpha_composite(layer, hardware)


def frame_all(raw_root: Path = PRODUCT / 'raw',
		output_root: Path = PRODUCT / 'intermediate' / 'duo-framed') -> list:
	"""Regenerate intermediate PNGs; safe to call after recapturing raw UI."""
	outputs = []
	for family in SCREENS:
		sources = sorted((raw_root / family).glob('*.png'))
		if not sources:
			raise ValueError(f'No PNG captures found in {raw_root / family}')
		for source in sources:
			output = output_root / family / source.name
			if output.resolve() == source.resolve():
				raise ValueError('Output must be separate from raw captures')
			image = frame_duo(source, family)
			output.parent.mkdir(parents=True, exist_ok=True)
			image.save(output)
			outputs.append(output)
	return outputs


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument('--raw-root', type=Path, default=PRODUCT / 'raw')
	parser.add_argument('--output-root', type=Path,
		default=PRODUCT / 'intermediate' / 'duo-framed')
	arguments = parser.parse_args()
	for output in frame_all(arguments.raw_root, arguments.output_root):
		print(output)
