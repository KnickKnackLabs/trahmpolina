#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).parent

for dirname in ("tiny-files", "shell-files"):
    directory = root / dirname
    if directory.exists():
        for path in directory.glob("*.bats"):
            path.unlink()
    directory.mkdir(exist_ok=True)

with (root / "tiny.bats").open("w") as f:
    f.write("#!/usr/bin/env bats\n\n")
    for i in range(64):
        f.write(f'@test "tiny {i:02d}" {{\n  true\n}}\n\n')

with (root / "shell.bats").open("w") as f:
    f.write("#!/usr/bin/env bats\n\n")
    for i in range(32):
        f.write(
            f'@test "shell {i:02d}" {{\n'
            '  local result="$BATS_TEST_TMPDIR/result"\n'
            f'  printf "%s\\n" "shell-{i:02d}" | tr "[:lower:]" "[:upper:]" > "$result"\n'
            f'  grep -q "SHELL-{i:02d}" "$result"\n'
            '  sleep 0.08\n'
            '}\n\n'
        )

for file_index in range(16):
    with (root / "tiny-files" / f"tiny-{file_index:02d}.bats").open("w") as f:
        f.write("#!/usr/bin/env bats\n\n")
        for test_index in range(4):
            f.write(
                f'@test "tiny file {file_index:02d} test {test_index:02d}" {{\n'
                '  true\n'
                '}\n\n'
            )

for file_index in range(8):
    with (root / "shell-files" / f"shell-{file_index:02d}.bats").open("w") as f:
        f.write("#!/usr/bin/env bats\n\n")
        for test_index in range(4):
            label = f"shell-{file_index:02d}-{test_index:02d}"
            f.write(
                f'@test "{label}" {{\n'
                '  local result="$BATS_TEST_TMPDIR/result"\n'
                f'  printf "%s\\n" "{label}" | tr "[:lower:]" "[:upper:]" > "$result"\n'
                f'  grep -q "{label.upper()}" "$result"\n'
                '  sleep 0.08\n'
                '}\n\n'
            )
