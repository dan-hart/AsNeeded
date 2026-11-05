#!/usr/bin/env python3
"""Exercise build wrappers with synthetic commands; never invoke Xcode."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildToolingTests(unittest.TestCase):
	def run_build(self, status=0, destination=None, formatter=True):
		with tempfile.TemporaryDirectory() as directory:
			bin_dir = Path(directory)
			commands = {
				"sysctl": "#!/bin/sh\necho 4\n",
				"xcodebuild": "#!/usr/bin/env python3\nimport json, os, sys\nwith open(os.environ['ARGUMENT_LOG'], 'w') as log: json.dump(sys.argv[1:], log)\nsys.exit(int(os.environ['BUILD_EXIT']))\n",
			}
			if formatter:
				commands["xcsift"] = "#!/bin/sh\ncat >/dev/null\nexit 0\n"
			for name, content in commands.items():
				path = bin_dir / name
				path.write_text(content)
				path.chmod(0o755)
			env = dict(os.environ, PATH=f"{directory}:/usr/bin:/bin", ARGUMENT_LOG=str(bin_dir / "args.json"), BUILD_EXIT=str(status))
			env.pop("BUILD_DESTINATION", None)
			if destination:
				env["BUILD_DESTINATION"] = destination
			result = subprocess.run(["bash", str(ROOT / "scripts/dev-build.sh")], env=env, capture_output=True, text=True)
			return result, json.loads((bin_dir / "args.json").read_text())

	def test_formatter_cannot_hide_build_failure(self):
		result, _ = self.run_build(status=65)
		self.assertNotEqual(result.returncode, 0, result.stdout)
		self.assertNotIn("Development build complete", result.stdout)

	def test_generic_destination_needs_no_installed_runtime(self):
		result, args = self.run_build()
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(args[args.index("-destination") + 1], "generic/platform=iOS Simulator")

	def test_destination_override_is_one_argument(self):
		destination = "platform=iOS Simulator,id=synthetic-device-id"
		result, args = self.run_build(destination=destination)
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(args[args.index("-destination") + 1], destination)

	def test_unformatted_build_failure_propagates(self):
		result, _ = self.run_build(status=65, formatter=False)
		self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
	unittest.main()
