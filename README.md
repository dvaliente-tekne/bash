# Bash Repository Structure Guide

A clean, Linux-first (Debian-friendly) structure for Bash utilities that keeps scripts **discoverable**, **testable**, and **CI-ready**. This README includes a reference layout, conventions, quality gates, examples, Makefile targets, and CI pipelines (GitHub Actions and Jenkins).

---

## ✅ Recommended Layout

```text
your-repo/
├─ bin/                    # User-facing executables (in PATH), no .sh suffix
│  ├─ foo
│  └─ bar
├─ lib/                    # Reusable libraries sourced by scripts
│  ├─ log.sh
│  ├─ fs.sh
│  └─ net.sh
├─ scripts/                # Internal/maintenance scripts (not user-facing)
│  └─ bootstrap-dev.sh
├─ modules/                # Optional: feature-specific groups of bin+lib
│  └─ backups/
│     ├─ bin/
│     └─ lib/
├─ completion/             # bash-completion files (optional)
│  └─ foo.bash
├─ tests/                  # Automated tests (bats-core)
│  ├─ helper.bash
│  ├─ foo.bats
│  └─ lib_log.bats
├─ docs/                   # Design notes, ADRs, reference
│  └─ architecture.md
├─ examples/               # Sample invocations or sample configs
│  └─ foo.env.example
├─ packaging/              # Optional: deb/rpm/homebrew/etc (Linux-first)
│  └─ debian/              # If you package for Debian/Ubuntu
├─ ci/                     # Jenkinsfile or reusable CI scripts
│  └─ Jenkinsfile
├─ .github/workflows/      # GitHub Actions (if you use GH CI)
│  └─ ci.yml
├─ .editorconfig
├─ .gitignore
├─ .pre-commit-config.yaml
├─ .shellcheckrc
├─ Makefile                # format, lint, test, package targets
├─ CHANGELOG.md
├─ CONTRIBUTING.md
├─ CODEOWNERS
├─ LICENSE
├─ README.md
└─ VERSION                 # Single source of truth for version
```

### What Goes Where (Quick Rules)
- **`bin/`**: Commands you expect users to run. No `.sh` suffix; mark executable (`chmod 755`). Keep CLI UX stable.
- **`lib/`**: Sourced helpers (logging, retries, fs, net). Non-executable (`chmod 644`). No side effects at import time.
- **`scripts/`**: Project maintenance utilities (e.g., `bootstrap-dev.sh`, codegen, local CI).
- **`tests/`**: Use `bats-core` for behavior tests; mirror `bin/` and `lib/` layout.
- **`completion/`**: `bash-completion` scripts for nicer UX.
- **`ci/`** and **`.github/workflows/`**: Jenkins/GitHub Actions pipelines.
- **Top-level files**: Project metadata, tooling, and common developer entrypoints.

---

## 🧰 Conventions (That Save You Later)

**Shebang & Strict Mode**
```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
```
- Use `bash` consistently; if you need pure POSIX, switch to `#!/usr/bin/env sh` in those scripts.
- Always quote variables, prefer `[[ ]]` for tests, avoid `eval`, use `mktemp` for temp files.

**Sourcing Libs Robustly**
```bash
# At top of bin/foo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/log.sh
source "${SCRIPT_DIR}/../lib/log.sh"
```
- Add `# shellcheck source=...` hints so ShellCheck can resolve paths.

**CLI Design**
- Prefer **no `.sh` suffix** for commands in `bin/`.
- Provide `--help` and `--version`. Keep defaults safe and idempotent.
- Use `getopts` for portable option parsing (GNU `getopt` is not installed everywhere).

**Permissions**
- Executables: `755`. Libraries/others: `644`. Keep the repo clean of executable bits where not needed.

---

## 🔒 Quality Gates: Format, Lint, Test

**Formatting: `shfmt`**
- Uniform style prevents noisy diffs.
```Makefile
format:
	shfmt -i 4 -ci -w bin lib scripts
```

**Linting: `shellcheck`**
- Catches quoting, array, and word-splitting bugs.
```Makefile
lint:
	shellcheck bin/* lib/*.sh scripts/*.sh
```

**Testing: `bats-core`**
- Write behavior tests that run fast on CI.
```Makefile
test:
	bats -r tests
```

**Pre-Commit Hooks**
Run `shfmt`, `shellcheck`, and optionally `bats` locally before pushes.
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.7.0
    hooks: [{ id: shfmt, args: ["-i", "4", "-ci"] }]
  - repo: https://github.com/corpix/shellcheck-precommit
    rev: v0.6.0
    hooks: [{ id: shellcheck }]
```

> **Debian install hints**
> ```bash
> sudo apt-get update
> sudo apt-get install -y shellcheck bats
> # shfmt: package may be available as 'shfmt' on newer Debian/Ubuntu; otherwise download static binary
> curl -sSLo /usr/local/bin/shfmt \
>   https://github.com/mvdan/sh/releases/latest/download/shfmt_linux_amd64
> chmod +x /usr/local/bin/shfmt
> ```

---

## 🧪 Example Files

**`bin/foo` (User-Facing Command)**
```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/log.sh
source "${SCRIPT_DIR}/../lib/log.sh"
VERSION_FILE="${SCRIPT_DIR}/../VERSION"

usage() {
  cat <<EOF
foo - example tool

Usage:
  foo [-n NAME] [--dry-run]
Options:
  -n NAME     Name to greet (default: world)
  --dry-run   Print what would happen without executing
  -h, --help  Show this help
  --version   Show version
EOF
}

NAME="world"
DRY_RUN=0

while (( "$#" )); do
  case "${1:-}" in
    -n) shift; NAME="${1:-}";;
    --dry-run) DRY_RUN=1;;
    -h|--help) usage; exit 0;;
    --version) cat "${VERSION_FILE}"; exit 0;;
    --) shift; break;;
    -*) die "Unknown flag: $1";;
    *) break;;
  esac
  shift || true

done

trap 'on_exit $?' EXIT
log_info "Starting foo (name=$NAME dry_run=$DRY_RUN)"

if (( DRY_RUN )); then
  log_warn "Dry run: would greet ${NAME}"
else
  echo "Hello, ${NAME}!"
fi
```

**`lib/log.sh` (Shared Logging)**
```bash
#!/usr/bin/env bash
# shellcheck shell=bash
LOG_LEVEL="${LOG_LEVEL:-INFO}"

_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_log() { local level="$1"; shift; printf "%s [%s] %s\n" "$(_ts)" "$level" "$*" >&2; }
log_debug(){ [[ "$LOG_LEVEL" == "DEBUG" ]] && _log "DEBUG" "$@"; }
log_info(){  _log "INFO"  "$@"; }
log_warn(){  _log "WARN"  "$@"; }
log_error(){ _log "ERROR" "$@"; }
die(){ log_error "$@"; exit 1; }
on_exit(){ local ec="$1"; (( ec==0 )) || log_error "Exited with code $ec"; }
```

**`tests/foo.bats`**
```bash
#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  PATH="${REPO_ROOT}/bin:${PATH}"
}

@test "foo prints hello with default name" {
  run foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world!"* ]]
}

@test "foo supports custom name" {
  run foo -n David
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, David!"* ]]
}
```

---

## ⚙️ Makefile (Developer UX)

```Makefile
SHELL := /usr/bin/env bash

.PHONY: all format lint test check install clean
all: check

format:
	shfmt -i 4 -ci -w bin lib scripts

lint:
	shellcheck bin/* lib/*.sh scripts/*.sh

test:
	bats -r tests

check: format lint test

install:
	install -d /usr/local/bin
	install -m 755 bin/* /usr/local/bin

clean:
	rm -rf dist build
```

---

## 🚦 CI Options

### GitHub Actions (`.github/workflows/ci.yml`)
```yaml
name: CI
on:
  push: { branches: ["main"] }
  pull_request:
jobs:
  bash:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install tools
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck bats
          curl -sSLo /usr/local/bin/shfmt https://github.com/mvdan/sh/releases/latest/download/shfmt_linux_amd64
          chmod +x /usr/local/bin/shfmt
      - run: make format
      - run: make lint
      - run: make test
```

### Jenkins (`ci/Jenkinsfile`)
```groovy
pipeline {
  agent any
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Tools') {
      steps {
        sh '''
          set -euo pipefail
          sudo apt-get update
          sudo apt-get install -y shellcheck bats
          curl -sSLo /usr/local/bin/shfmt https://github.com/mvdan/sh/releases/latest/download/shfmt_linux_amd64
          chmod +x /usr/local/bin/shfmt
        '''
      }
    }
    stage('Format') { steps { sh 'make format' } }
    stage('Lint')   { steps { sh 'make lint' } }
    stage('Test')   { steps { sh 'make test' } }
  }
  options { timestamps() }
}
```
