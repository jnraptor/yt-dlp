#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${PROJECT_DIR}/.venv"
PYTHON_BIN="${PYTHON:-python3}"
MODE="unix"   # unix | pyinstaller | sdist
JOBS=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [MODE] [extra pyinstaller args]

Modes:
  unix         (default) Build the platform-independent UNIX binary via 'make'
                          plus the sdist/wheel (what 'make all' does).
  pyinstaller  Build the standalone PyInstaller executable (matches README
                          'Standalone PyInstaller Builds' section). Extra args
                          are forwarded to 'python -m bundle.pyinstaller'
                          (e.g. --onefile / -F, --onedir / -D).
  sdist        Build only the sdist and wheel (no yt-dlp binary).

Environment:
  PYTHON=python3.12   Override the Python interpreter used for the venv.
EOF
}

case "${1:-}" in
    "")         MODE="unix" ;;
    unix)       MODE="unix" ;;
    pyinstaller) MODE="pyinstaller"; shift; JOBS=("$@") ;;
    sdist)      MODE="sdist" ;;
    -h|--|--help|help) usage; exit 0 ;;
    *)
        # Backwards compat: treat unknown first arg as pyinstaller extras
        MODE="pyinstaller"
        JOBS=("$@")
        ;;
esac

cd "${PROJECT_DIR}"

log() { printf '\033[1;34m[build]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build]\033[0m %s\n' "$*" >&2; }

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
    err "Python interpreter '${PYTHON_BIN}' not found on PATH"
    exit 1
fi

if [ ! -d "${VENV_DIR}" ]; then
    log "Creating virtual environment at ${VENV_DIR}"
    "${PYTHON_BIN}" -m venv "${VENV_DIR}"
else
    log "Reusing existing venv at ${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -m pip install --upgrade pip wheel

case "${MODE}" in
    unix)
        log "Installing project (editable) with build/default extras"
        pip install -e ".[default,build]"

        if command -v pandoc >/dev/null 2>&1; then
            log "Building docs + standalone UNIX binary (make all)"
            make all
        else
            log "pandoc missing: building docs sans manpage/README.txt + binary"
            make \
                README.md CONTRIBUTORS issuetemplates supportedsites \
                completion-bash completion-fish completion-zsh \
                lazy-extractors yt-dlp pypi-files
            log "Building sdist + wheel"
            python -m build -sn .
        fi

        log "Build complete. Artifacts:"
        ls -lh yt-dlp 2>/dev/null || true
        ls -lh dist/  2>/dev/null || true
        ;;

    pyinstaller)
        log "Installing pyinstaller dependency group via devscripts/install_deps.py"
        python devscripts/install_deps.py --include-group pyinstaller

        log "Generating lazy extractors"
        python devscripts/make_lazy_extractors.py

        log "Running pyinstaller bundle: python -m bundle.pyinstaller ${JOBS[*]-}"
        # shellcheck disable=SC2068
        python -m bundle.pyinstaller ${JOBS[@]-}

        log "PyInstaller build complete. Artifacts:"
        ls -lh dist/  2>/dev/null || true
        ;;

    sdist)
        log "Installing build tooling"
        pip install -e ".[default,build]"
        log "Preparing PyPI files and building sdist + wheel"
        make pypi-files
        python -m build -sn .
        log "Build complete. Artifacts:"
        ls -lh dist/ 2>/dev/null || true
        ;;

    *)
        err "Unknown mode: ${MODE}"
        usage
        exit 2
        ;;
esac

log "To activate the venv later: source ${VENV_DIR}/bin/activate"
