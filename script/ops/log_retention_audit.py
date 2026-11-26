"""Read-only host audit. Never emit log messages, environment values or credentials."""
import datetime
import json
from pathlib import Path
import re
import subprocess

LOG_OPTIONS = {"max-size", "max-file", "compress", "mode", "max-buffer-size"}
TIME = re.compile(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z) ")


def command(args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=30, check=False)
    if result.returncode:
        raise RuntimeError("Command failed: " + args[0])
    return result.stdout


def safe_logging(config):
    return {
        "driver": config.get("Type"),
        "options": {key: value for key, value in config.get("Config", {}).items() if key in LOG_OPTIONS},
        "other_option_names": sorted(set(config.get("Config", {})) - LOG_OPTIONS),
    }


def log_window(stdout, stderr):
    # Docker returns application stderr on stderr. Retain ONLY Docker timestamps.
    stamps = sorted(match.group(1) for line in (stdout + "\n" + stderr).splitlines()
                    if (match := TIME.match(line)))
    return {"timestamped_lines": len(stamps), "oldest_in_sample": stamps[0] if stamps else None,
            "newest_in_sample": stamps[-1] if stamps else None,
            "sample_limit_lines": 10000,
            "note": "Observed sample, not a guaranteed retention period; older rotated entries may exist."}


def inspect_container(container_id):
    if not re.fullmatch(r"[a-f0-9]{12,64}", container_id):
        raise ValueError("Invalid container ID")
    # Do not query Config.Env, mounts, network details or other secret-bearing fields.
    template = '{"name":{{json .Name}},"created":{{json .Created}},"running":{{json .State.Running}},"started":{{json .State.StartedAt}},"finished":{{json .State.FinishedAt}},"logging":{{json .HostConfig.LogConfig}}}'
    data = json.loads(command(["docker", "inspect", "--format", template, container_id]))
    name = data["name"].lstrip("/")
    if not (name == "kamal-proxy" or re.fullmatch(r"russ_live_de-(?:web|job)-hetzner-[a-f0-9]{40}", name)):
        raise ValueError("Unexpected container name")
    data["logging"] = safe_logging(data["logging"])
    try:
        logs = subprocess.run(["docker", "logs", "--timestamps", "--tail", "10000", container_id],
                              capture_output=True, text=True, timeout=30, check=False)
        data["log_sample"] = log_window(logs.stdout, logs.stderr) if logs.returncode == 0 else {"unavailable": True}
    except subprocess.TimeoutExpired:
        data["log_sample"] = {"unavailable": True, "reason": "Read timeout"}
    return data


def host_rotation():
    files = [Path("/etc/logrotate.conf")]
    directory = Path("/etc/logrotate.d")
    try:
        files += sorted(directory.iterdir())
    except PermissionError:
        return {"unavailable": True}
    relevant = []
    unreadable = []
    for path in files:
        try:
            content = path.read_text()
        except (PermissionError, FileNotFoundError, IsADirectoryError):
            unreadable.append(path.name)
            continue
        if re.search(r"docker|kamal|russ_live|/var/log/nginx", content, re.I):
            rules = re.findall(r"^\s*((?:daily|weekly|monthly|yearly|hourly|rotate|maxage|size|maxsize|minsize)\b[^\n#]*)", content, re.M)
            relevant.append({"file": str(path), "directives": [rule.strip() for rule in rules]})
    return {"matching_configs": relevant, "unreadable_files": unreadable,
            "scope": "Standard logrotate files only; custom jobs and backups require separate verification."}


def main():
    ids = command(["docker", "ps", "-aq", "--filter", "label=service=russ_live_de",
                   "--filter", "label=destination=hetzner"]).split()
    ids += command(["docker", "ps", "-aq", "--filter", "name=^/kamal-proxy$"]).split()
    if not ids:
        raise RuntimeError("No production containers found")
    report = {"checked_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "default_logging_driver": command(["docker", "info", "--format", "{{.LoggingDriver}}"]).strip(),
              "containers": [inspect_container(value) for value in dict.fromkeys(ids)],
              "host_logrotate": host_rotation(),
              "limitations": ["No log message contents are included.",
                              "Cloud snapshots, off-host copies and custom cleanup jobs are not verified.",
                              "Container creation and observed log age do not establish a fixed deletion deadline."]}
    try:
        daemon = json.loads(Path("/etc/docker/daemon.json").read_text())
        report["daemon_logging"] = safe_logging({"Type": daemon.get("log-driver"), "Config": daemon.get("log-opts", {})})
    except (PermissionError, FileNotFoundError, json.JSONDecodeError):
        report["daemon_logging"] = {"unavailable": True}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired):
        # Never include command stderr or tracebacks that may contain log messages.
        raise SystemExit("Read-only audit failed; no raw output disclosed.")
