#!/usr/bin/env python3
"""Classify canonical, high-entropy Base64 without printing candidate values.

Input is a staged blob on stdin. Known source identifiers, tracked path references,
and labeled reproducibility hashes are data; quoted unknown encoded values are not.
Provider-specific and generic credential checks run separately in the hook.
"""
import argparse
import base64
import binascii
from collections import Counter
import math
import re
import subprocess
import sys

CANDIDATE = re.compile(r"(?<![A-Za-z0-9+/])[A-Za-z0-9+/]{44,}={0,2}(?![A-Za-z0-9+/=])")


def entropy(value):
	return -sum((count / len(value)) * math.log2(count / len(value)) for count in Counter(value).values())


def canonical(value):
	try:
		decoded = base64.b64decode(value + '=' * (-len(value) % 4), validate=True)
		return base64.b64encode(decoded).decode().rstrip('=') == value.rstrip('=')
	except (ValueError, binascii.Error):
		return False


def swift_code_mask(text):
	"""Mask comments and strings, including multiline/raw literals, before classification."""
	mask = list(text)
	pattern = re.compile(r'(?P<comment>//[^\n]*|/\*[\s\S]*?\*/)|(?P<string>\#*"""[\s\S]*?"""\#*|\#*"(?:\\[\s\S]|[^"\\])*"\#*)')
	for match in pattern.finditer(text):
		mask[match.start():match.end()] = ['\n' if char == '\n' else ' ' for char in match.group()]
	return ''.join(mask)


def is_hash(path, line, value):
	if not re.fullmatch(r'[a-fA-F0-9]{64}', value):
		return False
	if re.search(r'\bSHA[-_ ]?256\b', line, re.I):
		return True
	return path.endswith('Package.resolved') and bool(re.search(r'"originHash"\s*:\s*"' + re.escape(value) + r'"', line))


def findings(text, path, tracked_paths=()):
	code = swift_code_mask(text) if path.endswith('.swift') else ''
	line_offset = 0
	for number, full_line in enumerate(text.splitlines(keepends=True), 1):
		line = full_line.rstrip('\r\n')
		for match in CANDIDATE.finditer(line):
			value = match.group()
			if not canonical(value) or entropy(value.rstrip('=')) < 4.5:
				continue
			if is_hash(path, line, value):
				continue
			if any(value in tracked and tracked in line for tracked in tracked_paths):
				continue
			if code and re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', value):
				start, end = line_offset + match.start(), line_offset + match.end()
				if code[start:end] == value:
					before, after = code[:start], code[end:]
					if re.search(r'(?:\.|\b(?:func|let|var|case|struct|class|enum|protocol|typealias)\s+)$', before) or re.match(r'\s*\(', after):
						continue
			yield number
		line_offset += len(full_line)


def main():
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument('--path', required=True)
	parser.add_argument('--revision', help='Resolve known paths from this commit instead of the index')
	args = parser.parse_args()
	blob = sys.stdin.buffer.read()
	if b'\0' in blob:
		return 0
	path_command = ['git', 'ls-tree', '-r', '-z', '--name-only', args.revision] if args.revision else ['git', 'ls-files', '-z']
	paths = subprocess.check_output(path_command).decode('utf-8', errors='replace').split('\0')
	lines = sorted(set(findings(blob.decode('utf-8', errors='replace'), args.path, paths)))
	for line in lines:
		print(f'{args.path}:{line}: potential encoded secret (value redacted)')
	return bool(lines)


if __name__ == '__main__':
	sys.exit(main())
