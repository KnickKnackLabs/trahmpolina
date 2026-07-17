#!/usr/bin/env python3
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import time

root = Path(__file__).parent
bats = Path(sys.argv[1])
rush = Path(sys.argv[2])
cpu = os.cpu_count() or 2
candidates = list(dict.fromkeys([1, 2, 4, cpu]))
profiles = [root / "tiny-files", root / "shell-files"]
results = {profile.name: {str(j): [] for j in candidates} for profile in profiles}

def command(profile: Path, jobs: int) -> list[str]:
    args = [str(bats), "--jobs", str(jobs), "--parallel-binary-name", str(rush)]
    if jobs > 1:
        args.append("--no-parallelize-within-files")
    args.append(str(profile))
    return args

for profile in profiles:
    for jobs in candidates:
        subprocess.run(command(profile, jobs), check=True, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)

for round_index in range(5):
    order = candidates[round_index % len(candidates):] + candidates[:round_index % len(candidates)]
    if round_index % 2:
        order.reverse()
    for profile in profiles:
        for jobs in order:
            start = time.perf_counter()
            completed = subprocess.run(command(profile, jobs), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            elapsed = time.perf_counter() - start
            if completed.returncode:
                print(completed.stdout, file=sys.stderr)
                raise SystemExit(completed.returncode)
            results[profile.name][str(jobs)].append(elapsed)

payload = {
    "mode": "rush cross-file; within-file serial",
    "cpu_count": cpu,
    "bats": subprocess.check_output([str(bats), "--version"], text=True).strip(),
    "rush": subprocess.check_output([str(rush), "--version"], text=True).splitlines()[0],
    "runs": results,
    "summary": {},
}
for profile, rows in results.items():
    payload["summary"][profile] = {}
    for jobs, values in rows.items():
        payload["summary"][profile][jobs] = {
            "median_s": statistics.median(values),
            "mean_s": statistics.mean(values),
            "min_s": min(values),
            "max_s": max(values),
        }

(root / "results-cross-file.json").write_text(json.dumps(payload, indent=2) + "\n")
print(json.dumps(payload["summary"], indent=2))
