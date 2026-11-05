#!/usr/bin/env python3
"""Run storage-review shell steps against synthetic events and repositories."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/storage-review.yml"


def step_script(name):
	text = WORKFLOW.read_text().split(f"      - name: {name}\n", 1)[1]
	text = text.split("        run: |\n", 1)[1].split("\n      - name:", 1)[0]
	return "\n".join(line[10:] if line.startswith("          ") else line for line in text.splitlines())


class StorageReviewTests(unittest.TestCase):
	def test_entire_push_range_includes_earlier_storage_commit(self):
		with tempfile.TemporaryDirectory() as directory:
			repo = Path(directory)
			def git(*args):
				return subprocess.check_output(["git", *args], cwd=repo, text=True).strip()
			git("init", "-q")
			git("config", "user.email", "fixture@example.invalid")
			git("config", "user.name", "Synthetic Fixture")
			(repo / "README.md").write_text("initial\n")
			git("add", ".")
			git("commit", "-qm", "initial")
			before = git("rev-parse", "HEAD")
			(repo / "DataStore.swift").write_text("// synthetic storage fixture\n")
			git("add", ".")
			git("commit", "-qm", "storage")
			(repo / "README.md").write_text("later non-storage commit\n")
			git("add", ".")
			git("commit", "-qm", "later")
			after = git("rev-parse", "HEAD")
			for base in (before, "0" * 40):
				with self.subTest(base=base):
					output = repo / "output"
					output.write_text("")
					env = dict(os.environ, EVENT_NAME="push", BEFORE_SHA=base, AFTER_SHA=after, GITHUB_OUTPUT=str(output))
					result = subprocess.run(["bash", "-euo", "pipefail", "-c", step_script("Check for storage-sensitive changes")], cwd=repo, env=env, text=True, capture_output=True)
					self.assertEqual(result.returncode, 0, result.stderr)
					self.assertIn("storage_changes_found=true", output.read_text())

	def test_pr_body_is_data_and_cannot_execute_shell(self):
		with tempfile.TemporaryDirectory() as directory:
			marker = Path(directory) / "injected"
			body = f'MIGRATION_REVIEWED $(touch "{marker}") `touch "{marker}"` "'
			result = subprocess.run(["bash", "-euo", "pipefail", "-c", step_script("Check for migration acknowledgment (PR only)")], env=dict(os.environ, PR_BODY=body), text=True, capture_output=True)
			self.assertEqual(result.returncode, 0, result.stderr)
			self.assertFalse(marker.exists())

	def test_missing_acknowledgment_fails(self):
		result = subprocess.run(["bash", "-euo", "pipefail", "-c", step_script("Check for migration acknowledgment (PR only)")], env=dict(os.environ, PR_BODY="ordinary description"), text=True, capture_output=True)
		self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
	unittest.main()
