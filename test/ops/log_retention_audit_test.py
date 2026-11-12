import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("audit", Path(__file__).parents[2] / "script/ops/log_retention_audit.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class LogRetentionAuditTest(unittest.TestCase):
    def test_log_messages_and_unstructured_errors_never_leave_the_host(self):
        report = audit.log_window("2026-11-10T10:00:00.000Z ip=192.0.2.1 token=SECRET\n",
                                  "permission error SECRET\n2026-11-11T12:00:00.000Z email=private@example.com\n")
        self.assertEqual(report["timestamped_lines"], 2)
        self.assertEqual(report["oldest_in_sample"], "2026-11-10T10:00:00.000Z")
        self.assertNotIn("SECRET", str(report))
        self.assertNotIn("private@example.com", str(report))
        self.assertEqual(report["sample_limit_lines"], 10000)

    def test_logging_credentials_are_not_reported(self):
        report = audit.safe_logging({"Type": "json-file", "Config": {"max-size": "10m", "max-file": "3", "token": "SECRET"}})
        self.assertEqual(report["options"], {"max-size": "10m", "max-file": "3"})
        self.assertNotIn("SECRET", str(report))

    def test_invalid_container_ids_never_run_a_command(self):
        with patch.object(audit, "command") as command:
            with self.assertRaises(ValueError):
                audit.inspect_container("; touch /tmp/unwanted")
            command.assert_not_called()

    def test_unrelated_container_is_rejected_before_reading_logs(self):
        with patch.object(audit, "command", return_value='{"name":"/stuttgart_live_de-web"}'), patch.object(audit.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                audit.inspect_container("a" * 64)
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
