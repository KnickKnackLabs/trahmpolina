#!/usr/bin/env bash
# Shared fixtures for template tests.

# Run a repo task through mise so tests exercise the real task path.
template() {
  cd "$REPO_DIR" && mise run -q "$@"
}
export -f template

# Run the public task with only the environment needed by real concurrency
# probes, excluding the per-test mock BATS and Rush commands.
template_isolated() {
  env -i \
    HOME="$HOME" \
    PATH="$PATH" \
    TMPDIR="${TMPDIR:-/tmp}" \
    MISE_TRUSTED_CONFIG_PATHS="$REPO_DIR" \
    PROBE_DIR="${PROBE_DIR:-}" \
    mise -C "$REPO_DIR" run -q "$@"
}
export -f template_isolated
