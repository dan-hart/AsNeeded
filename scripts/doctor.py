#!/usr/bin/env python3
"""Report local build prerequisites without repairs, downloads, or secret access."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

LOCKFILE = 'AsNeeded.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'


def observe(command, root):
	"""Run a fixed read-only observation; never include raw diagnostic output."""
	try:
		result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=30)
		return result.stdout.strip() if result.returncode == 0 else None
	except (OSError, subprocess.TimeoutExpired, UnicodeError):
		return None


def version(value):
	match = re.search(r'\b(\d+)\.(\d+)(?:\.(\d+))?', value or '')
	return tuple(int(part or 0) for part in match.groups()) if match else None


def diagnose(root, run=observe):
	checks = []
	def add(name, success, message, remedy, optional=False):
		checks.append({'id': name, 'status': 'pass' if success else ('warning' if optional else 'failure'), 'message': message if success else remedy})

	selected = run(['xcode-select', '-p'], root)
	xcode = run(['xcodebuild', '-version'], root)
	xcode_version = version(xcode)
	add('xcode', bool(selected and xcode_version and xcode_version >= (26, 0, 0)), 'Xcode 26 or newer is selected.', 'Select a full Xcode 26+ installation and complete its first-launch setup manually.')
	try:
		project = (root / 'AsNeeded.xcodeproj/project.pbxproj').read_text()
		targets = [version(item) for item in re.findall(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([\d.]+)', project)]
		deployment = max(item for item in targets if item)
	except (OSError, ValueError, UnicodeError):
		deployment = None
	add('deployment', deployment is not None, 'Project iOS deployment targets were read.', 'Restore the project file with a valid iOS deployment target.')
	sdk = version(run(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], root))
	add('sdk', bool(deployment and sdk and sdk >= deployment), 'Selected iOS Simulator SDK meets the deployment target.', 'Select Xcode with an iOS Simulator SDK at or above the project deployment target.')
	compiler = version(run(['xcrun', 'swift', '--version'], root))
	add('compiler', bool(compiler and compiler >= (6, 2, 0)), 'Selected Swift compiler is 6.2 or newer.', 'Select Xcode with Swift 6.2 or newer.')
	inventory = run(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'], root)
	compatible = False
	try:
		devices = json.loads(inventory or '').get('devices', {})
		for runtime, entries in devices.items():
			match = re.fullmatch(r'com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?', runtime)
			runtime_version = tuple(int(part or 0) for part in match.groups()) if match else None
			if deployment and runtime_version and runtime_version >= deployment:
				compatible |= any(item.get('isAvailable') is True and str(item.get('name', '')).startswith('iPhone') for item in entries)
	except (ValueError, AttributeError, TypeError):
		compatible = False
	add('simulators', compatible, 'An available deployment-compatible iPhone simulator exists.', 'Could not confirm a compatible iPhone simulator. Check CoreSimulator access, then installed runtimes/devices in Xcode; doctor makes no changes.')
	pinned = False
	try:
		lock = json.loads((root / LOCKFILE).read_text())
		pins = lock.get('pins', [])
		pinned = lock.get('version') in (2, 3) and isinstance(pins, list) and bool(pins)
		identities = set()
		for pin in pins:
			identity = pin.get('identity')
			revision = pin.get('state', {}).get('revision', '')
			pinned = pinned and isinstance(identity, str) and bool(identity) and identity not in identities and bool(re.fullmatch(r'[a-fA-F0-9]{40}', revision))
			identities.add(identity)
	except (OSError, ValueError, AttributeError, TypeError, UnicodeError):
		pinned = False
	add('packages', bool(pinned), 'Package.resolved contains nonempty, uniquely identified revision pins.', 'Restore a valid committed Package.resolved; doctor does not resolve or fetch packages.')
	hooks_path = run(['git', 'config', '--get', 'core.hooksPath'], root)
	configured = bool(hooks_path and (root / hooks_path).resolve() == (root / '.githooks').resolve())
	hooks = configured and all(os.access(root / '.githooks' / hook, os.X_OK) for hook in ('pre-commit', 'pre-push'))
	add('hooks', hooks, 'Repository security hooks are selected and executable.', 'Review scripts/install-hooks.sh and configure repository security hooks manually.')
	scanner = all((root / path).is_file() and os.access(root / path, os.X_OK) for path in ('scripts/scan-repo.sh', 'scripts/utilities/asp-preflight.sh'))
	scanner = scanner and (root / 'scripts/utilities/base64-secret-scan.py').is_file() and os.access(root / 'scripts/utilities/base64-secret-scan.py', os.R_OK)
	add('scanner', scanner, 'Repository shell scanners are executable and Python helper is readable (not run).', 'Restore repository scanner/preflight helpers, shell executable permissions, and Python helper read access.')
	config = (root / 'Config/Secrets.xcconfig').is_file() or 'REVENUECAT_API_KEY' in os.environ
	add('purchase_config', config, 'Optional purchase configuration is present; values and validity were not inspected.', 'Optional purchase configuration is absent; tipping/subscriptions may be unavailable. See Config/Secrets.example.xcconfig.', optional=True)
	return {'ok': not any(check['status'] == 'failure' for check in checks), 'checks': checks}


def main(argv=None):
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument('--json', action='store_true', help='Print a machine-readable report to stdout.')
	parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1], help='Repository checkout to inspect (default: this script’s checkout).')
	args = parser.parse_args(argv)
	report = diagnose(args.root.resolve())
	if args.json:
		print(json.dumps(report, indent=2))
	else:
		for check in report['checks']:
			print(f"[{check['status'].upper()}] {check['id']}: {check['message']}")
	return 0 if report['ok'] else 1


if __name__ == '__main__':
	raise SystemExit(main())
