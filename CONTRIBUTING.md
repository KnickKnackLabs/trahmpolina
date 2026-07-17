# Contributing

This repo is the KnickKnackLabs starter skeleton for small maintained tools.
Keep it boring on purpose: new repos should inherit conventions without inheriting product decisions.

## Structure

```text
template/
├── mise.toml              # Tools, settings, codebase lint config
├── README.tsx             # Source for generated README.md
├── README.md              # Generated; keep in sync with README.tsx
├── CONTRIBUTING.md        # Repo orientation surface
├── .mise/tasks/test       # Canonical BATS runner
├── .mise/tasks/doctor     # Local health checks + optional hook status
├── lib/                   # Shared runtime code for copied tools
└── test/                  # BATS tests and helpers
```

## Local setup

```bash
mise trust
mise install
mise run test
mise run doctor
```

`doctor` reports whether the optional local `codebase pre-commit` hook is installed.
Install it in your clone when you want convention lints to run before every commit:

```bash
codebase pre-commit
```

The hook lives under `.git/hooks/`, so it is intentionally not tracked by the repo.

## Parallel test contract

`mise run test` uses Rush to schedule separate `.bats` files with a measured
four-job default. Tests inside each file remain serial because BATS 1.13's
within-file semaphore polling is disproportionately slow for short tests.

Override the measured default when needed:

```bash
mise run test --jobs 4
BATS_NUMBER_OF_PARALLEL_JOBS=2 mise run test
mise run test --jobs 1  # serial debugging
```

Parallel tests must isolate mutable state per test and process. Prefer
`$BATS_TEST_TMPDIR`, unique ports, and fixture-local repositories. Do not share
fixed files, services, HOME overrides, or repository mutations across tests. A
copied suite that is not yet isolated should opt into one job until it is safe.

## README workflow

Edit `README.tsx`, then regenerate and check the output:

```bash
readme build
readme build --check
```

CI also checks that `README.md` matches `README.tsx`.

## When copying this template

1. Rename the project constants in `README.tsx`.
1. Replace this guide with codebase-specific orientation.
1. Add real shared code under `lib/` only after at least two tasks need it.
1. Keep tests calling tasks through `mise run`, not by invoking `.mise/tasks/*` directly.
1. If the tool resolves caller-relative paths after shiv install, use the package-scoped `<PACKAGE>_CALLER_PWD` variable.
1. Keep parallel tests isolated per test/process, or use one job until shared state is removed.

## Validation before merge

```bash
mise run test
codebase lint "$PWD"
readme build --check
git diff --check
```
