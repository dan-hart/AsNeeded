#!/usr/bin/env python3
"""Exercise the release gate with synthetic artifacts, no signing or network."""
from datetime import datetime, timedelta, timezone
import importlib.util
import os
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/release-handoff.py'


class ReleaseHandoffTests(unittest.TestCase):
	def setUp(self):
		self.directory = tempfile.TemporaryDirectory()
		self.addCleanup(self.directory.cleanup)
		self.root = Path(self.directory.name)
		spec = importlib.util.spec_from_file_location('release_handoff', SCRIPT)
		self.release = importlib.util.module_from_spec(spec)
		spec.loader.exec_module(self.release)

	def write_plist(self, path, value):
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_bytes(plistlib.dumps(value, fmt=plistlib.FMT_BINARY))

	def artifact(self):
		app = self.root / 'AsNeeded.app'
		self.signatures = {}
		for relative, bundle_id in self.release.BUNDLES.items():
			bundle = app / relative
			info = {
				'CFBundleIdentifier': bundle_id,
				'CFBundleShortVersionString': '1.3.0',
				'CFBundleVersion': '327',
				'CFBundleExecutable': 'FixtureExecutable',
			}
			if relative == '.':
				info['NSDocumentsFolderUsageDescription'] = 'Synthetic permission text'
				info['UIBackgroundModes'] = ['remote-notification', 'fetch', 'processing']
			if relative.startswith('Watch/'):
				info['UIBackgroundModes'] = ['remote-notification']
			self.write_plist(bundle / 'Info.plist', info)
			(bundle / 'FixtureExecutable').touch()
			self.signatures[bundle] = {
				'application-identifier': f'SYNTHETICT.{bundle_id}',
				'com.apple.developer.team-identifier': 'SYNTHETICT',
				'get-task-allow': False,
				'beta-reports-active': True,
				**self.release.APP_CAPABILITIES[relative],
			}
		watch = app / 'Watch/WristAsNeeded Watch App.app'
		self.signatures[watch]['aps-environment'] = 'production'
		self.signatures[watch]['com.apple.developer.icloud-container-environment'] = 'Production'
		for relative, manifest in self.release.PRIVACY_MANIFESTS.items():
			self.write_plist(app / relative, manifest)
		self.addCleanup(patch.stopall)
		patch.object(self.release, 'signed_entitlements', side_effect=self.signatures.__getitem__).start()
		patch.object(self.release, 'linked_libraries', return_value='').start()
		return app

	def test_expected_signed_artifact(self):
		app = self.artifact()
		targets = self.release.inspect_app(app, '1.3.0', '327', 'SYNTHETICT', exported=True)
		self.assertEqual({item['bundle_id'] for item in targets}, set(self.release.BUNDLES.values()))

	def test_rejects_mismatched_widget_build(self):
		app = self.artifact()
		path = app / 'PlugIns/AsNeededWidgetExtension.appex/Info.plist'
		info = plistlib.loads(path.read_bytes())
		info['CFBundleVersion'] = '326'
		self.write_plist(path, info)
		with self.assertRaisesRegex(self.release.ReleaseError, 'version/build'):
			self.release.inspect_app(app, '1.3.0', '327', 'SYNTHETICT', exported=True)

	def test_rejects_health_permission_in_localized_info(self):
		app = self.artifact()
		self.write_plist(app / 'fr.lproj/InfoPlist.strings', {'NSHealthShareUsageDescription': 'synthetic'})
		with self.assertRaisesRegex(self.release.ReleaseError, 'NSHealthShareUsageDescription'):
			self.release.inspect_app(app, '1.3.0', '327', 'SYNTHETICT', exported=True)

	def test_rejects_tracking_in_embedded_sdk(self):
		app = self.artifact()
		path = app / 'RevenueCat_RevenueCat.bundle/PrivacyInfo.xcprivacy'
		manifest = plistlib.loads(path.read_bytes())
		manifest['NSPrivacyTrackingDomains'] = ['synthetic.invalid']
		self.write_plist(path, manifest)
		with self.assertRaisesRegex(self.release.ReleaseError, 'privacy manifest'):
			self.release.inspect_app(app, '1.3.0', '327', 'SYNTHETICT', exported=True)

	def test_rejects_unknown_entitlement_and_debuggable_export(self):
		for key, value in [('com.apple.developer.healthkit', True), ('get-task-allow', True)]:
			with self.subTest(key=key):
				app = self.artifact()
				self.signatures[app][key] = value
				with self.assertRaisesRegex(self.release.ReleaseError, key):
					self.release.inspect_app(app, '1.3.0', '327', 'SYNTHETICT', exported=True)

	def test_storekit_fixtures_are_kept_out_of_app_resources(self):
		project = (ROOT / 'AsNeeded.xcodeproj/project.pbxproj').read_text()
		for name in ('ANStoreKitConfig.storekit', 'StoreKitTestCertificate.cer'):
			self.assertNotIn(f'{name} in Resources', project)
			self.assertTrue((ROOT / name).is_file())

	def test_rejects_storekit_test_and_exported_data_payloads(self):
		app = self.artifact()
		for name in ('StoreKitTestCertificate.cer', 'ANStoreKitConfig.storekit', 'synthetic-history.json', 'synthetic.sqlite-wal'):
			with self.subTest(name=name):
				payload = app / name
				payload.touch()
				with self.assertRaisesRegex(self.release.ReleaseError, 'payload'):
					self.release.inspect_app(app, '1.3.0', '327', 'SYNTHETICT', exported=True)
				payload.unlink()

	def test_archive_and_ipa_expected_bundles_are_unambiguous(self):
		archive = self.root / 'Fixture.xcarchive'
		products = archive / 'Products/Applications'
		(products / 'AsNeeded.app').mkdir(parents=True)
		(products / 'Surprise.app').mkdir()
		with self.assertRaisesRegex(self.release.ReleaseError, 'exactly one'):
			self.release.only_app(products)
		ipa = self.root / 'Fixture.ipa'
		with zipfile.ZipFile(ipa, 'w') as zipped:
			zipped.writestr('../outside', 'synthetic')
		with self.assertRaisesRegex(self.release.ReleaseError, 'unsafe ZIP entry'):
			self.release.unpack_ipa(ipa, self.root / 'unpacked')

	def test_reads_codesign_der_display_without_silently_skipping_keys(self):
		der_display = b'[Dict]\n\t[Key] example\n\t[Value]\n\t\t[Array]\n\t\t\t[String] fixture\n\t[Key] extra\n\t[Value]\n\t\t[Bool] true\n'
		self.assertEqual(self.release.decode_entitlements(der_display), {'example': ['fixture'], 'extra': True})
		with self.assertRaisesRegex(self.release.ReleaseError, 'entitlements'):
			self.release.decode_entitlements(der_display.replace(b'[Bool]', b'[Unknown]'))

	def test_ipa_profile_must_be_unexpired_exact_and_for_app_store(self):
		bundle_id = self.release.BUNDLES['.']
		team = 'SYNTHETICT'
		future = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=1)
		profile = {
			'TeamIdentifier': [team],
			'ExpirationDate': future,
			'Entitlements': {
				'application-identifier': f'{team}.{bundle_id}',
				'get-task-allow': False,
				'beta-reports-active': True,
			},
		}
		with patch.object(self.release, 'command', return_value=plistlib.dumps(profile)):
			self.release.inspect_profile(self.root, bundle_id, team, exported=True)
		for unexpected in ({'ProvisionedDevices': ['synthetic-device']}, {'ExpirationDate': datetime(2001, 1, 1)}, {'TeamIdentifier': ['WRONGTEAMX']}):
			with self.subTest(unexpected=unexpected), patch.object(self.release, 'command', return_value=plistlib.dumps({**profile, **unexpected})):
				with self.assertRaisesRegex(self.release.ReleaseError, 'profile'):
					self.release.inspect_profile(self.root, bundle_id, team, exported=True)

	@unittest.skipUnless(sys.platform == 'darwin', 'The export helper uses macOS plutil.')
	def test_existing_export_helper_refuses_upload_options(self):
		options = self.root / 'ExportOptions.plist'
		self.write_plist(options, {'method': 'app-store-connect', 'destination': 'upload'})
		archive = self.root / 'AsNeeded.xcarchive'
		archive.mkdir()
		marker = self.root / 'asc-was-called'
		asc = self.root / 'asc'
		asc.write_text('#!/bin/sh\ntouch "$EXPORT_TEST_MARKER"\n')
		asc.chmod(0o755)
		result = subprocess.run(['/bin/bash', str(ROOT / 'scripts/export-testflight.sh'), str(archive), str(self.root / 'AsNeeded.ipa')],
			env={**os.environ, 'PATH': f'{self.root}:/usr/bin:/bin', 'ASNEEDED_EXPORT_OPTIONS': str(options), 'EXPORT_TEST_MARKER': str(marker)},
			capture_output=True, text=True)
		self.assertNotEqual(result.returncode, 0)
		self.assertIn('local export', result.stderr)
		self.assertFalse(marker.exists())

	def test_export_options_must_use_local_export_and_fixed_versions(self):
		options = self.root / 'ExportOptions.plist'
		self.write_plist(options, {'method': 'app-store-connect', 'destination': 'upload', 'manageAppVersionAndBuildNumber': False})
		with self.assertRaisesRegex(self.release.ReleaseError, 'local export'):
			self.release.check_export_options(options)
		self.write_plist(options, {'method': 'app-store-connect', 'manageAppVersionAndBuildNumber': True})
		with self.assertRaisesRegex(self.release.ReleaseError, 'manageAppVersionAndBuildNumber'):
			self.release.check_export_options(options)

	def test_dirty_source_is_rejected_before_running_xcode(self):
		env = {**os.environ, 'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_SYSTEM': '/dev/null'}
		subprocess.run(['/usr/bin/git', 'init', '-q', str(self.root)], env=env, check=True)
		(self.root / 'unexpected').touch()
		with self.assertRaisesRegex(self.release.ReleaseError, 'clean checkout'):
			self.release.source_revision(self.root)

	def test_handoff_receipt_rejects_empty_or_failed_test_evidence(self):
		for total, failed in [(0, 0), (5, 1)]:
			summary = json.dumps({'result': 'Passed', 'totalTestCount': total, 'failedTests': failed, 'passedTests': total - failed, 'skippedTests': 0})
			with self.subTest(total=total, failed=failed), patch.object(self.release, 'command', return_value=summary.encode()):
				with self.assertRaisesRegex(self.release.ReleaseError, 'test result'):
					self.release.test_summary(self.root / 'Synthetic.xcresult')

	def test_requires_simulator_destination_and_no_conflicting_platform(self):
		for valid in ('', 'platform=iOS Simulator,id=synthetic', 'platform=iOS Simulator,name=iPhone 17,OS=26.5'):
			self.release.check_test_destination(valid)
		for invalid in ('platform=iOS,id=synthetic', 'generic/platform=iOS Simulator', 'platform=iOS Simulator,id=one,platform=iOS'):
			with self.subTest(invalid=invalid), self.assertRaisesRegex(self.release.ReleaseError, 'iOS Simulator'):
				self.release.check_test_destination(invalid)

	def test_release_rejects_ignored_content_in_synchronized_roots(self):
		with patch.object(self.release, 'command', side_effect=[b'', b'AsNeeded/local-test-payload.swift']):
			with self.assertRaisesRegex(self.release.ReleaseError, 'ignored files'):
				self.release.reviewed_source_revision(self.root)

	def test_local_key_config_rejects_additional_build_settings(self):
		config = self.root / 'Secrets.xcconfig'
		config.write_text('// Synthetic key\nREVENUECAT_API_KEY = appl_SyntheticExample // placeholder for test\n')
		self.release.check_local_key_config(config)
		for extra in ('#include "other.xcconfig"', 'OTHER_SETTING = value', 'REVENUECAT_API_KEY = appl_Second'):
			with self.subTest(extra=extra):
				config.write_text(f'REVENUECAT_API_KEY = appl_SyntheticExample\n{extra}\n')
				with self.assertRaisesRegex(self.release.ReleaseError, 'only the RevenueCat'):
					self.release.check_local_key_config(config)

	def test_export_signature_requires_apple_distribution_team_and_identifier(self):
		def signed_product(args, **kwargs):
			for arg in args:
				if str(arg).startswith('--extract-certificates='):
					Path(str(arg).split('=', 1)[1] + '0').write_bytes(b'synthetic-leaf')
			return b''

		with patch.object(self.release, 'command', side_effect=signed_product) as execute:
			leaf = self.release.verify_signed_product(self.root, 'com.example.synthetic', 'SYNTHETICT', exported=True)
		self.assertEqual(leaf, b'synthetic-leaf')
		verify_arguments = execute.call_args_list[0].args[0]
		requirement = verify_arguments[verify_arguments.index('-R') + 1]
		self.assertIn('anchor apple generic', requirement)
		self.assertIn('certificate leaf[field.1.2.840.113635.100.6.1.4]', requirement)
		self.assertIn('certificate leaf[subject.OU] = "SYNTHETICT"', requirement)
		self.assertIn('identifier "com.example.synthetic"', requirement)

	def test_trusted_profile_must_match_product_signing_leaf(self):
		bundle_id = 'com.example.synthetic'
		team = 'SYNTHETICT'
		profile = {
			'TeamIdentifier': [team], 'ExpirationDate': datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=1),
			'Entitlements': {'application-identifier': f'{team}.{bundle_id}'}, 'DeveloperCertificates': [b'synthetic-leaf'],
		}
		roots = self.root / 'apple-roots.pem'
		roots.touch()
		with patch.object(self.release, 'read_profile', return_value=profile):
			self.release.inspect_profile(self.root, bundle_id, team, exported=False, trusted_roots=roots, leaf=b'synthetic-leaf')
			with self.assertRaisesRegex(self.release.ReleaseError, 'signing certificate'):
				self.release.inspect_profile(self.root, bundle_id, team, exported=False, trusted_roots=roots, leaf=b'different-leaf')


	def test_trusted_profile_requires_apple_cms_signing_extension(self):
		def profile_tool(args, **kwargs):
			if args[1] == 'smime':
				self.assertIn('-CAfile', args)
				self.assertNotIn('-noverify', args)
				args[args.index('-signer') + 1].write_bytes(b'fixture\n-----END CERTIFICATE-----\n')
				return plistlib.dumps({'synthetic': True})
			return b'    X509v3 Basic Constraints:\n        CA:FALSE\n'

		with patch.object(self.release, 'command', side_effect=profile_tool):
			with self.assertRaisesRegex(self.release.ReleaseError, 'Apple profile signing certificate extension'):
				self.release.read_profile(self.root / 'synthetic.mobileprovision', self.root / 'apple-roots.pem')

	def test_receipt_keeps_test_counts_and_runtime_without_device_identifier(self):
		summary = {
			'result': 'Passed', 'totalTestCount': 5, 'failedTests': 0, 'passedTests': 4, 'skippedTests': 1,
			'expectedFailures': 0, 'devicesAndConfigurations': [{'device': {'osVersion': '26.5', 'deviceId': 'private-device'}}],
		}
		with patch.object(self.release, 'command', return_value=json.dumps(summary).encode()):
			evidence = self.release.test_summary(self.root / 'Synthetic.xcresult')
		self.assertEqual(evidence, {'totalTestCount': 5, 'failedTests': 0, 'passedTests': 4, 'skippedTests': 1,
			'expectedFailures': 0, 'runtimes': ['26.5']})

	def test_debug_symbols_must_match_both_built_copies(self):
		archive = self.root / 'AsNeeded.xcarchive'
		archive_app = archive / 'Products/Applications/AsNeeded.app'
		exported_app = self.root / 'Payload/AsNeeded.app'
		for relative in self.release.BUNDLES:
			for bundle in (archive_app / relative, exported_app / relative):
				self.write_plist(bundle / 'Info.plist', {'CFBundleExecutable': 'FixtureExecutable'})
			symbols = archive / 'dSYMs' / ((archive_app / relative).name + '.dSYM')
			symbols.mkdir(parents=True)
		matching = b'UUID: 00000000-0000-0000-0000-000000000001 (arm64) Fixture\n'
		wrong = b'UUID: 00000000-0000-0000-0000-000000000002 (arm64) Fixture\n'
		with patch.object(self.release, 'command', return_value=matching):
			self.assertEqual(len(self.release.verify_debug_symbols(archive, archive_app, exported_app)), 3)
		with patch.object(self.release, 'command', side_effect=[matching, wrong, matching]):
			with self.assertRaisesRegex(self.release.ReleaseError, 'UUID'):
				self.release.verify_debug_symbols(archive, archive_app, exported_app)

	def test_crash_review_is_scoped_to_the_exact_processed_build(self):
		build = {
			'data': {'id': 'fixture-build', 'attributes': {'version': '328', 'processingState': 'VALID', 'expired': False}},
			'included': [{'type': 'preReleaseVersions', 'attributes': {'version': '1.3.0', 'platform': 'IOS'}}],
		}
		reports = {'data': [{'id': 'fixture-crash', 'attributes': {'feedback': 'private fixture'}}], 'links': {}}
		metrics = {'data': [{'type': 'betaBuildUsages', 'dataPoints': [{'values': {'crashCount': 2, 'sessionCount': 6}}]}]}
		with patch.object(self.release, 'command', side_effect=[json.dumps(item).encode() for item in (build, reports, metrics)]) as command:
			result = self.release.testflight_crash_summary('1.3.0', '328')
			self.assertEqual(result, {'build_id': 'fixture-build', 'crash_submissions': 1, 'recorded_crashes': 2, 'reported_sessions': 6})
			self.assertIn('fixture-build', command.call_args.args[0])
			self.assertIn('--paginate', command.call_args_list[1].args[0])
		build['data']['attributes']['version'] = '327'
		with patch.object(self.release, 'command', return_value=json.dumps(build).encode()):
			with self.assertRaisesRegex(self.release.ReleaseError, 'expected processed'):
				self.release.testflight_crash_summary('1.3.0', '328')

	def test_crash_review_blocks_promotion_when_a_report_exists(self):
		archive = self.root / 'AsNeeded.xcarchive'
		(archive / 'Products/Applications/AsNeeded.app').mkdir(parents=True)
		ipa = self.root / 'AsNeeded.ipa'
		with zipfile.ZipFile(ipa, 'w') as fixture:
			fixture.writestr('Payload/AsNeeded.app/Info.plist', b'synthetic')
		receipt = {
			'source_revision': 'fixture-revision',
			'artifacts': {
				archive.name: {'tree_sha256': self.release.sha256_tree(archive)},
				ipa.name: {'sha256': self.release.sha256_file(ipa)},
			},
			'bundle_audit': {
				'signature_trust_verified': True,
				'ipa': [{'bundle_id': bundle, 'version': '1.3.0', 'build': '328'} for bundle in self.release.BUNDLES.values()],
			},
		}
		(self.root / 'release-receipt.json').write_text(json.dumps(receipt))
		for feedback, crashes, sessions, message in [(1, 0, 1, 'before promoting'), (0, 1, 1, 'before promoting'),
			(0, 0, 0, 'reported beta sessions'), (0, 0, 1, None)]:
			with self.subTest(feedback=feedback, crashes=crashes, sessions=sessions), patch.object(
				self.release, 'verify_debug_symbols', return_value={}
			), patch.object(self.release, 'testflight_crash_summary', return_value={
				'build_id': 'fixture-build', 'crash_submissions': feedback, 'recorded_crashes': crashes, 'reported_sessions': sessions,
			}), patch('builtins.print'):
				if message is None:
					self.release.review_testflight_crashes(self.root, '1.3.0', '328')
				else:
					with self.assertRaisesRegex(self.release.ReleaseError, message):
						self.release.review_testflight_crashes(self.root, '1.3.0', '328')
		ipa.write_bytes(b'modified')
		with self.assertRaisesRegex(self.release.ReleaseError, 'no longer match'):
			self.release.review_testflight_crashes(self.root, '1.3.0', '328')

	def test_checkout_provenance_rejects_an_unpinned_local_dependency(self):
		state = {'object': {'dependencies': [{'packageRef': {'identity': 'local-dependency'}, 'state': {'name': 'fileSystem'}}]}}
		(self.root / 'workspace-state.json').write_text(json.dumps(state))
		with self.assertRaisesRegex(self.release.ReleaseError, 'package identities'):
			self.release.verify_checkouts(self.root, {})

	def test_artifact_tree_digest_records_file_contents_and_paths(self):
		fixture = self.root / 'artifact'
		fixture.write_text('one')
		initial = self.release.sha256_tree(self.root)
		fixture.write_text('two')
		changed = self.release.sha256_tree(self.root)
		self.assertNotEqual(initial, changed)
		fixture.rename(self.root / 'different-name')
		self.assertNotEqual(changed, self.release.sha256_tree(self.root))


if __name__ == '__main__':
	unittest.main()
