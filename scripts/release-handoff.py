#!/usr/bin/env python3
"""Prepare a local AsNeeded release or audit an existing archive/IPA."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'AsNeeded.xcodeproj'
LOCKFILE = Path(PROJECT) / 'project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
APP_ID = 'com.codedbydan.AsNeeded'
SYNCHRONIZED_ROOTS = ('AsNeeded', 'AsNeededTests', 'AsNeededWidget', 'WristAsNeeded Watch App')
SYSTEM_ROOTS = '/System/Library/Keychains/SystemRootCertificates.keychain'
APPLE_PROFILE_SIGNING_OID = '1.2.840.113635.100.6.58'
WIDGET = 'PlugIns/AsNeededWidgetExtension.appex'
WATCH = 'Watch/WristAsNeeded Watch App.app'
BUNDLES = {'.': APP_ID, WIDGET: f'{APP_ID}.AsNeededWidget', WATCH: f'{APP_ID}.watchkitapp'}
GROUP = {'com.apple.security.application-groups': [f'group.{APP_ID}']}
APP_CAPABILITIES = {
	'.': {**GROUP, 'com.apple.developer.siri': True, 'com.apple.developer.usernotifications.time-sensitive': True},
	WIDGET: GROUP,
	WATCH: {
		**GROUP,
		'com.apple.developer.siri': True,
		'com.apple.developer.icloud-container-identifiers': ['iCloud.com.codedbydan.AsNeededContainer'],
		'com.apple.developer.icloud-services': ['CloudKit'],
	},
}
BACKGROUND_MODES = {'.': {'remote-notification', 'fetch', 'processing'}, WATCH: {'remote-notification'}}
DOCUMENT_PERMISSION = 'NSDocumentsFolderUsageDescription'
SDK_BUNDLES = {'RevenueCat_RevenueCat.bundle', 'RevenueCat_RevenueCatUI.bundle'}
GENERATED_JSON = {'Metadata.appintents/version.json', f'{WIDGET}/Metadata.appintents/version.json'}
REVIEW_PAYLOAD = re.compile(
	r'(^\.env(?:\.|$)|\.(?:json|csv|tsv|zip|log|xcconfig|storekit|cer|pem|p12|key|p8|sqlite3?|db)(?:$|[-~])|^Secrets\.plist$)',
	re.IGNORECASE,
)


def manifest(accessed, collected=(), *, sdk=False):
	return {
		'NSPrivacyTracking': False,
		**({} if sdk else {'NSPrivacyTrackingDomains': []}),
		'NSPrivacyCollectedDataTypes': [
			{
				'NSPrivacyCollectedDataType': f'NSPrivacyCollectedDataType{kind}',
				'NSPrivacyCollectedDataTypeLinked': False,
				'NSPrivacyCollectedDataTypeTracking': False,
				'NSPrivacyCollectedDataTypePurposes': [f'NSPrivacyCollectedDataTypePurpose{purpose}' for purpose in purposes],
			}
			for kind, purposes in collected
		],
		'NSPrivacyAccessedAPITypes': [
			{'NSPrivacyAccessedAPIType': f'NSPrivacyAccessedAPICategory{kind}', 'NSPrivacyAccessedAPITypeReasons': reasons}
			for kind, reasons in accessed.items()
		],
	}


# Deliberate review policy, independent of the manifests copied from the app and SDK sources.
PRIVACY_MANIFESTS = {
	'PrivacyInfo.xcprivacy': manifest(
		{'UserDefaults': ['CA92.1', '1C8F.1'], 'FileTimestamp': ['C617.1', '3B52.1'], 'DiskSpace': ['E174.1']},
		[(kind, ['Analytics', 'AppFunctionality']) for kind in ('PurchaseHistory', 'SearchHistory')],
	),
	f'{WIDGET}/PrivacyInfo.xcprivacy': manifest({'UserDefaults': ['1C8F.1']}),
	'RevenueCat_RevenueCat.bundle/PrivacyInfo.xcprivacy': manifest(
		{'UserDefaults': ['CA92.1']}, [('PurchaseHistory', ['AppFunctionality'])], sdk=True,
	),
}


class ReleaseError(Exception):
	pass


def require(condition, message):
	if not condition:
		raise ReleaseError(message)


def command(args, *, cwd=ROOT, env=None, log=None):
	if log is None:
		result = subprocess.run(args, cwd=cwd, env=env, capture_output=True, check=False)
	else:
		with log.open('xb') as stream:
			result = subprocess.run(args, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT, check=False)
	require(result.returncode == 0, f'{Path(args[0]).name} failed ({result.returncode}).'
		+ (f' See private {log.name}.' if log else ''))
	return result.stdout


def read_plist(path):
	data = plistlib.loads(path.read_bytes())
	require(isinstance(data, dict), f'Expected a plist dictionary in {path.name}.')
	return data


def decode_entitlements(data):
	if not data.startswith(b'[Dict]'):
		try:
			value = plistlib.loads(data)
		except plistlib.InvalidFileException as error:
			raise ReleaseError('Could not decode signed entitlements.') from error
		require(isinstance(value, dict), 'Signed entitlements are not a dictionary.')
		return value

	# Current codesign prints DER-only signatures as a typed tree. Parse the expected
	# flat dictionary with scalar values or string arrays, and fail closed on other shapes.
	lines = iter(data.decode().splitlines()[1:])
	entitlements = {}
	line = next(lines, None)
	while line is not None:
		require(line.startswith('\t[Key] '), 'Unexpected signed entitlements format.')
		key = line.removeprefix('\t[Key] ')
		require(key not in entitlements and next(lines, '') == '\t[Value]', 'Unexpected signed entitlements format.')
		value = next(lines, '')
		line = next(lines, None)
		if value == '\t\t[Array]':
			items = []
			while line is not None and line.startswith('\t\t\t[String] '):
				items.append(line.removeprefix('\t\t\t[String] '))
				line = next(lines, None)
			entitlements[key] = items
		elif value.startswith('\t\t[String] '):
			entitlements[key] = value.removeprefix('\t\t[String] ')
		elif value in ('\t\t[Bool] true', '\t\t[Bool] false'):
			entitlements[key] = value.endswith('true')
		else:
			raise ReleaseError('Unexpected signed entitlements value type.')
	return entitlements


def signed_entitlements(bundle):
	return decode_entitlements(command(['/usr/bin/codesign', '-d', '--entitlements', '-', bundle]))


def linked_libraries(executable):
	return command(['/usr/bin/otool', '-L', executable]).decode()


def inspect_entitlements(bundle, relative, bundle_id, team_id, *, exported):
	actual = signed_entitlements(bundle)
	expected = {
		**APP_CAPABILITIES[relative],
		'application-identifier': f'{team_id}.{bundle_id}',
		'com.apple.developer.team-identifier': team_id,
	}
	if relative == WATCH:
		expected['aps-environment'] = 'production' if exported else actual.get('aps-environment')
		require(expected['aps-environment'] in ('development', 'production'), 'Watch push environment is invalid.')
	if exported:
		expected.update({'get-task-allow': False, 'beta-reports-active': True})
		if relative == WATCH:
			expected['com.apple.developer.icloud-container-environment'] = 'Production'
	else:
		# A Release archive can be development-signed. Distribution is enforced on the IPA.
		for key in ('get-task-allow', 'beta-reports-active'):
			if key in actual:
				require(type(actual[key]) is bool, f'{bundle_id}: invalid {key} entitlement.')
				expected[key] = actual[key]
		if relative == WATCH and 'com.apple.developer.icloud-container-environment' in actual:
			environment = 'Production' if expected['aps-environment'] == 'production' else 'Development'
			expected['com.apple.developer.icloud-container-environment'] = environment
	for key in sorted(actual.keys() | expected.keys()):
		require(key in actual and key in expected and normalized(actual[key]) == normalized(expected[key]),
			f'{bundle_id}: unexpected, missing or changed entitlement {key}.')


def normalized(value):
	"""Ignore declaration order while retaining type, value and duplicate entries."""
	if isinstance(value, list):
		return sorted(normalized(item) for item in value)
	if isinstance(value, dict):
		return sorted((key, normalized(item)) for key, item in value.items())
	return json.dumps(value)


def inspect_permission_keys(info, allowed, location):
	keys = {key for key in info if 'UsageDescription' in key or key in ('NSAppTransportSecurity', 'NSBonjourServices')}
	for key in sorted(keys - allowed):
		raise ReleaseError(f'{location}: unexpected permission or transport declaration {key}.')


def inspect_app(app, version, build, team_id, *, exported):
	paths = {path.relative_to(app).as_posix(): path for path in app.rglob('*')}
	require(not any(path.is_symlink() for path in paths.values()), 'Unexpected symbolic link in application payload.')
	embedded = {name for name, path in paths.items() if path.suffix in ('.app', '.appex')}
	require(embedded == BUNDLES.keys() - {'.'}, 'Unexpected or missing embedded app/extension.')
	require(not any(path.suffix in ('.framework', '.dylib') for path in paths.values()), 'Unexpected embedded dynamic library/framework.')
	require({name for name, path in paths.items() if path.suffix == '.bundle'} <= SDK_BUNDLES, 'Unexpected embedded resource bundle.')
	manifests = {name for name, path in paths.items() if path.name == 'PrivacyInfo.xcprivacy'}
	require(manifests == PRIVACY_MANIFESTS.keys(), 'Unexpected or missing privacy manifest.')
	for name, expected in PRIVACY_MANIFESTS.items():
		require(normalized(read_plist(paths[name])) == normalized(expected), f'{name}: privacy manifest differs from reviewed declarations.')
	for name, path in paths.items():
		if REVIEW_PAYLOAD.search(path.name):
			require(name in GENERATED_JSON, 'Unexpected test, signing, or data payload in the application bundle.')
		if path.name == 'InfoPlist.strings' or path.name == 'Info.plist':
			allowed = {DOCUMENT_PERMISSION} if '/' not in name or name.count('/') == 1 and '.lproj/' in name else set()
			inspect_permission_keys(read_plist(path), allowed, name)

	targets = []
	for relative, bundle_id in BUNDLES.items():
		bundle = app / relative
		info = read_plist(bundle / 'Info.plist')
		require(info.get('CFBundleIdentifier') == bundle_id, f'{relative}: unexpected bundle identifier.')
		require((info.get('CFBundleShortVersionString'), info.get('CFBundleVersion')) == (version, build),
			f'{bundle_id}: expected version/build {version} ({build}).')
		if relative == '.':
			require(bool(info.get(DOCUMENT_PERMISSION)), 'App backup folder usage description is missing.')
		require(set(info.get('UIBackgroundModes', [])) == BACKGROUND_MODES.get(relative, set()),
			f'{bundle_id}: unexpected background modes.')
		executable = info.get('CFBundleExecutable', '')
		require(executable and Path(executable).name == executable and (bundle / executable).is_file(),
			f'{bundle_id}: bundle executable is missing.')
		require(not re.search(r'(?:CareKit|HealthKit|AppTrackingTransparency)\.framework', linked_libraries(bundle / executable)),
			f'{bundle_id}: unexpected linked health or tracking framework.')
		inspect_entitlements(bundle, relative, bundle_id, team_id, exported=exported)
		targets.append({'bundle_id': bundle_id, 'version': version, 'build': build})
	return targets


def only_app(directory):
	app = directory / 'AsNeeded.app'
	require(directory.is_dir() and list(directory.iterdir()) == [app] and app.is_dir() and not app.is_symlink(),
		'Expected exactly one AsNeeded.app in the application payload.')
	return app


def unpack_ipa(ipa, destination):
	with zipfile.ZipFile(ipa) as zipped:
		seen = set()
		for entry in zipped.infolist():
			name = PurePosixPath(entry.filename)
			mode = stat.S_IFMT(entry.external_attr >> 16)
			require(name.parts and not name.is_absolute() and '..' not in name.parts and '\\' not in entry.filename
				and name.as_posix().casefold() not in seen and mode in (0, stat.S_IFDIR, stat.S_IFREG), 'IPA contains an unsafe ZIP entry.')
			seen.add(name.as_posix().casefold())
			root = name.parts[0]
			require(root == 'Payload' or (root == 'Symbols' and (entry.is_dir() or name.suffix == '.symbols'))
				or (root == 'SwiftSupport' and (entry.is_dir() or name.suffix == '.dylib')),
				'IPA contains an unexpected top-level payload.')
			if root == 'Payload' and len(name.parts) > 1:
				require(name.parts[1] == 'AsNeeded.app', 'IPA contains an unexpected application payload.')
	command(['/usr/bin/unzip', '-q', ipa, '-d', destination])


def verify_signed_product(bundle, bundle_id, team_id, *, exported):
	terms = [f'identifier "{bundle_id}"', 'anchor apple generic',
		'certificate 1[field.1.2.840.113635.100.6.2.1] exists', f'certificate leaf[subject.OU] = "{team_id}"']
	if exported:
		terms.append('certificate leaf[field.1.2.840.113635.100.6.1.4] exists')
	command(['/usr/bin/codesign', '--verify', '--strict', '-R', '=' + ' and '.join(terms), bundle])
	with tempfile.TemporaryDirectory(prefix='asneeded-cert-') as directory:
		prefix = Path(directory) / 'product-'
		command(['/usr/bin/codesign', '-d', f'--extract-certificates={prefix}', bundle])
		return prefix.with_name('product-0').read_bytes()


def read_profile(path, trusted_roots):
	args = ['/usr/bin/openssl', 'smime', '-verify', '-inform', 'DER', '-in', path]
	if trusted_roots is None:
		return plistlib.loads(command([*args, '-noverify']))
	with tempfile.TemporaryDirectory(prefix='asneeded-profile-') as directory:
		signer = Path(directory) / 'profile-signer.pem'
		profile = command([*args, '-purpose', 'any', '-CAfile', trusted_roots, '-CApath', directory, '-signer', signer])
		require(signer.read_bytes().splitlines().count(b'-----END CERTIFICATE-----') == 1,
			'Expected a single provisioning profile signer.')
		certificate = command(['/usr/bin/openssl', 'x509', '-in', signer, '-noout', '-text']).decode()
		require(re.search(rf'^\s+{re.escape(APPLE_PROFILE_SIGNING_OID)}:\s*(?:critical)?$', certificate, re.MULTILINE),
			'Provisioning profile signer lacks the Apple profile signing certificate extension.')
		return plistlib.loads(profile)


def inspect_profile(bundle, bundle_id, team_id, *, exported, trusted_roots=None, leaf=None):
	profile = read_profile(bundle / 'embedded.mobileprovision', trusted_roots)
	entitlements = profile['Entitlements']
	require(profile.get('TeamIdentifier') == [team_id] and entitlements.get('application-identifier') == f'{team_id}.{bundle_id}',
		f'{bundle_id}: provisioning profile team or identifier does not match.')
	require(profile['ExpirationDate'].replace(tzinfo=timezone.utc) > datetime.now(timezone.utc),
		f'{bundle_id}: provisioning profile expired.')
	if leaf is not None:
		require(leaf in profile.get('DeveloperCertificates', []), f'{bundle_id}: signing certificate does not match its profile.')
	if exported:
		require('ProvisionedDevices' not in profile and not profile.get('ProvisionsAllDevices')
			and entitlements.get('get-task-allow') is False and entitlements.get('beta-reports-active') is True,
			f'{bundle_id}: IPA requires an App Store distribution profile.')


def audit(archive, ipa, version, build, team_id, *, verify_signatures=False):
	archive_app = only_app(archive / 'Products/Applications')
	archive_targets = inspect_app(archive_app, version, build, team_id, exported=False)
	with tempfile.TemporaryDirectory(prefix='asneeded-ipa-') as directory:
		scratch = Path(directory)
		unpack_ipa(ipa, scratch)
		exported_app = only_app(scratch / 'Payload')
		export_targets = inspect_app(exported_app, version, build, team_id, exported=True)
		trusted_roots = None
		if verify_signatures:
			trusted_roots = scratch / 'apple-roots.pem'
			roots = command(['/usr/bin/security', 'find-certificate', '-a', '-c', 'Apple Root CA', '-p', SYSTEM_ROOTS])
			require(b'-----END CERTIFICATE-----' in roots.splitlines(), 'The system Apple root certificates are unavailable.')
			trusted_roots.write_bytes(roots)
		for app, exported in ((archive_app, False), (exported_app, True)):
			if verify_signatures:
				command(['/usr/bin/codesign', '--verify', '--deep', '--strict', app])
			for relative, bundle_id in BUNDLES.items():
				bundle = app / relative
				leaf = verify_signed_product(bundle, bundle_id, team_id, exported=exported) if verify_signatures else None
				inspect_profile(bundle, bundle_id, team_id, exported=exported, trusted_roots=trusted_roots, leaf=leaf)
	return {'archive': archive_targets, 'ipa': export_targets, 'signature_trust_verified': verify_signatures}


def check_export_options(path):
	options = read_plist(path)
	require(options.get('destination', 'export') == 'export' and options.get('method') in ('app-store-connect', 'app-store'),
		'ExportOptions.plist must specify local export with an App Store distribution method.')
	require(options.get('manageAppVersionAndBuildNumber') is False,
		'ExportOptions.plist must set manageAppVersionAndBuildNumber to false.')
	return options


def require_clean_checkout(root):
	require(not command(['/usr/bin/git', 'status', '--porcelain', '--untracked-files=all'], cwd=root),
		'The release handoff requires a clean checkout (including untracked files).')


def source_revision(root):
	require_clean_checkout(root)
	return command(['/usr/bin/git', 'rev-parse', 'HEAD'], cwd=root).decode().strip()


def reviewed_source_revision(root):
	require_clean_checkout(root)
	require(not command(['/usr/bin/git', 'ls-files', '--others', '--ignored', '--exclude-standard', '--', *SYNCHRONIZED_ROOTS], cwd=root),
		'The release handoff forbids ignored files in Xcode synchronized source roots.')
	return command(['/usr/bin/git', 'rev-parse', 'HEAD'], cwd=root).decode().strip()


def check_local_key_config(path):
	require(path.is_file() and not path.is_symlink(), 'The local RevenueCat config must be a regular file.')
	data = path.read_bytes()
	lines = [line.strip() for line in data.decode().splitlines() if line.strip() and not line.lstrip().startswith('//')]
	require(len(lines) == 1 and re.fullmatch(r'REVENUECAT_API_KEY[ \t]*=[ \t]*[A-Za-z0-9_-]+[ \t]*(?://.*)?', lines[0]),
		'The local config must contain only the RevenueCat public SDK key assignment and line comments.')
	return hashlib.sha256(data).digest()


def check_test_destination(destination):
	if not destination:
		return
	parts = [part.split('=', 1) for part in destination.split(',')]
	require(all(len(part) == 2 and part[1] for part in parts), 'Use a concrete iOS Simulator test destination.')
	fields = dict(parts)
	require(len(fields) == len(parts) and fields.get('platform') == 'iOS Simulator'
		and fields.keys() <= {'platform', 'id', 'name', 'OS'} and len({'id', 'name'} & fields.keys()) == 1,
		'Use a concrete iOS Simulator test destination.')


def sha256_file(path):
	digest = hashlib.sha256()
	with path.open('rb') as stream:
		for block in iter(lambda: stream.read(1024 * 1024), b''):
			digest.update(block)
	return digest.hexdigest()


def sha256_tree(path):
	# Include paths, permissions, file contents and symlink targets. Timestamps are excluded.
	digest = hashlib.sha256()
	for item in sorted(path.rglob('*')):
		mode = item.lstat().st_mode
		if item.is_symlink():
			value = os.readlink(item)
		elif item.is_file():
			value = sha256_file(item)
		else:
			require(item.is_dir(), 'Artifact tree contains an unsupported entry.')
			value = None
		digest.update(json.dumps([item.relative_to(path).as_posix(), mode, value]).encode() + b'\n')
	return digest.hexdigest()


def dependency_pins():
	records = json.loads((ROOT / LOCKFILE).read_bytes())['pins']
	pins = {record['identity']: record['state']['revision'] for record in records}
	require(pins and len(pins) == len(records) and all(re.fullmatch(r'[a-f0-9]{40}', value) for value in pins.values()),
		'Package.resolved must contain unique dependency revision pins.')
	return pins


def verify_checkouts(packages, pins):
	state = json.loads((packages / 'workspace-state.json').read_bytes())
	dependencies = state['object']['dependencies']
	checkouts = {
		item['packageRef']['identity']: item['subpath'] for item in dependencies
		if item['state']['name'] == 'sourceControlCheckout'
	}
	require(len(dependencies) == len(checkouts) and checkouts.keys() == pins.keys(), 'Resolved Swift package identities differ from Package.resolved.')
	for identity, subpath in sorted(checkouts.items()):
		require(Path(subpath).name == subpath, 'Unexpected Swift package checkout path.')
		require(source_revision(packages / 'checkouts' / subpath) == pins[identity],
			f'Checked-out revision differs from Package.resolved for {identity}.')


def test_summary(result_path):
	result = json.loads(command(['/usr/bin/xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', result_path]))
	require(result['result'] == 'Passed' and result['totalTestCount'] > 0 and result['passedTests'] > 0
		and result['failedTests'] == 0, 'The release test result must contain passing tests and zero failures.')
	return {
		**{key: result[key] for key in ('totalTestCount', 'passedTests', 'failedTests', 'skippedTests', 'expectedFailures')},
		'runtimes': sorted({entry['device']['osVersion'] for entry in result['devicesAndConfigurations']}),
	}


def prepare(args):
	revision = reviewed_source_revision(ROOT)
	check_test_destination(os.environ.get('TEST_DESTINATION', ''))
	key_config = ROOT / 'Config/Secrets.xcconfig'
	key_fingerprint = check_local_key_config(key_config)
	require(not os.environ.get('XCODE_XCCONFIG_FILE'), 'Unset XCODE_XCCONFIG_FILE before preparing a release.')
	options_path = Path(os.environ.get('ASNEEDED_EXPORT_OPTIONS', Path.home() / 'Library/Developer/AsNeeded/Signing/ExportOptions.plist'))
	options = check_export_options(options_path)
	require(options.get('teamID', args.team_id) == args.team_id, 'ExportOptions.plist uses a different team.')
	output = args.output.resolve()
	require(ROOT not in output.parents and output != ROOT, 'Place release output outside the checkout.')
	require(output.parent.is_dir() and not output.exists(), 'Choose a new output directory with an existing parent.')
	pins = dependency_pins()
	lock_sha = sha256_file(ROOT / LOCKFILE)
	xcode = command(['/usr/bin/xcodebuild', '-version']).decode().strip()
	command([ROOT / 'scripts/verify-release-key.sh', '--local'])
	output.mkdir(mode=0o700)
	archive = output / 'AsNeeded.xcarchive'
	ipa = output / 'AsNeeded.ipa'
	tests = output / 'AsNeeded.xcresult'
	derived = output / 'DerivedData'
	packages = output / 'SourcePackages'
	pinned = ['-onlyUsePackageVersionsFromResolvedFile', '-clonedSourcePackagesDirPath', str(packages)]
	print('Running the AsNeeded simulator suite. See private tests.log for progress.', flush=True)
	command([ROOT / 'scripts/test-parallel.sh'], env={
		**os.environ, 'TEST_RESULT_BUNDLE_PATH': str(tests), 'TEST_DERIVED_DATA_PATH': str(derived),
		'TEST_PINNED_PACKAGES_PATH': str(packages), 'TEST_WITHOUT_BUILDING': '0',
		'TEST_DISABLE_REVENUECAT': '1', 'TEST_PARALLEL_ENABLED': 'NO',
	}, log=output / 'tests.log')
	evidence = test_summary(tests)
	verify_checkouts(packages, pins)
	print('Archiving the Release scheme for iOS.', flush=True)
	command(['/usr/bin/xcodebuild', '-project', PROJECT, '-scheme', 'AsNeeded', '-configuration', 'Release',
		'-destination', 'generic/platform=iOS', '-derivedDataPath', str(derived), '-archivePath', str(archive),
		*pinned, 'archive'], log=output / 'archive.log')
	verify_checkouts(packages, pins)
	command([ROOT / 'scripts/verify-release-key.sh', archive])
	inspect_app(only_app(archive / 'Products/Applications'), args.version, args.build, args.team_id, exported=False)
	print('Exporting an App Store IPA locally.', flush=True)
	with tempfile.TemporaryDirectory(prefix='asneeded-export-', dir=output) as directory:
		local_options = Path(directory) / 'ExportOptions.plist'
		local_options.write_bytes(plistlib.dumps(options))
		if shutil.which('asc'):
			command([ROOT / 'scripts/export-testflight.sh', archive, ipa],
				env={**os.environ, 'ASNEEDED_EXPORT_OPTIONS': str(local_options)}, log=output / 'export.log')
		else:
			exported = Path(directory) / 'Export'
			command(['/usr/bin/xcodebuild', '-exportArchive', '-archivePath', archive, '-exportPath', exported,
				'-exportOptionsPlist', local_options], log=output / 'export.log')
			ipas = list(exported.glob('*.ipa'))
			require(len(ipas) == 1, 'Xcode export must produce exactly one IPA.')
			ipas[0].rename(ipa)
	checked = audit(archive, ipa, args.version, args.build, args.team_id, verify_signatures=True)
	command([ROOT / 'scripts/verify-release-key.sh', ipa])
	require(reviewed_source_revision(ROOT) == revision and sha256_file(ROOT / LOCKFILE) == lock_sha,
		'Source revision or package lock changed during release preparation.')
	require(check_local_key_config(key_config) == key_fingerprint, 'The local key config changed during release preparation.')
	receipt = {
		'schema_version': 1,
		'created_at_utc': datetime.now(timezone.utc).isoformat(timespec='seconds'),
		'source_revision': revision,
		'xcode': xcode,
		'package_resolved_sha256': lock_sha,
		'dependency_revisions': pins,
		'artifacts': {archive.name: {'tree_sha256': sha256_tree(archive)}, ipa.name: {'sha256': sha256_file(ipa)}},
		'tests': {**evidence, 'result_bundle': tests.name, 'tree_sha256': sha256_tree(tests)},
		'bundle_audit': checked,
	}
	with (output / 'release-receipt.json').open('x') as stream:
		json.dump(receipt, stream, indent=2, sort_keys=True)
		stream.write('\n')
	print('Verified archive and IPA. Wrote release-receipt.json.')


def main():
	parser = argparse.ArgumentParser(description=__doc__)
	modes = parser.add_subparsers(dest='mode', required=True)
	prepare_parser = modes.add_parser('prepare', help='Test, archive, export locally and record provenance.')
	prepare_parser.add_argument('--output', type=Path, required=True, help='New private directory outside the checkout.')
	audit_parser = modes.add_parser('audit', help='Check an existing archive and IPA without building.')
	audit_parser.add_argument('--archive', type=Path, required=True)
	audit_parser.add_argument('--ipa', type=Path, required=True)
	audit_parser.add_argument('--verify-signatures', action='store_true', help='Also verify signature integrity and local trust.')
	for mode in (prepare_parser, audit_parser):
		mode.add_argument('--version', required=True)
		mode.add_argument('--build', required=True)
		mode.add_argument('--team-id', required=True, help='Expected Apple Developer team ID.')
	args = parser.parse_args()
	try:
		require(re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', args.version) and re.fullmatch(r'[0-9]+', args.build),
			'Use a three-part marketing version and a numeric build number.')
		require(re.fullmatch(r'[A-Z0-9]{10}', args.team_id), 'Supply the expected 10-character Apple Developer team ID.')
		if args.mode == 'prepare':
			prepare(args)
		else:
			print(json.dumps(audit(args.archive.resolve(), args.ipa.resolve(), args.version, args.build, args.team_id,
				verify_signatures=args.verify_signatures), indent=2))
	except ReleaseError as error:
		parser.exit(1, f'Release check failed. {error}\n')
	except (OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
		parser.exit(1, f'Release check could not read required evidence ({type(error).__name__}).\n')


if __name__ == '__main__':
	main()
