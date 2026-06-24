#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${PROJECT_DIR}/.venv"
PYTHON_BIN="${PYTHON:-python3}"
MODE="unix"
JOBS=()

CHANNEL="${CHANNEL:-stable}"
ORIGIN="${ORIGIN:-local}"
VERSION="${VERSION:-}"
SKIP_PREPARE="${SKIP_PREPARE:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [MODE] [extra pyinstaller args]

Modes:
  unix         (default) Run the same steps as the CI 'unix' job in
                          .github/workflows/build.yml:
                              update-version -> update_changelog ->
                              make_lazy_extractors -> 'make all-extra tar'
                          If pandoc is missing this falls back to
                          'make yt-dlp-extra' (binary only, per the
                          README note that pandoc is not needed for the
                          binary).
  pyinstaller  Build the standalone PyInstaller executable (matches
                          README 'Standalone PyInstaller Builds' section).
                          Extra args are forwarded to
                          'python -m bundle.pyinstaller'
                          (e.g. --onefile/-F, --onedir/-D).
  sdist        Build only the sdist + wheel (requires pandoc).

Environment:
  PYTHON=python3.12    Override the Python interpreter used for the venv.
  CHANNEL=stable        Update channel passed to update-version.py
                        (matches workflow input.channel).
  ORIGIN=local          Update origin passed to update-version.py
                        (matches workflow input.origin / repo).
  VERSION=YYYY.MM.DD    Version to stamp into yt_dlp/version.py
                        (matches workflow input.version). Empty = let
                        update-version.py auto-generate from the date.
  SKIP_PREPARE=1        Skip the update-version / update_changelog /
                        make_lazy_extractors prepare steps. The Makefile
                        will still run make_lazy_extractors as needed.
EOF
}

case "${1:-}" in
    "")          MODE="unix" ;;
    unix)        MODE="unix" ;;
    pyinstaller) MODE="pyinstaller"; shift; JOBS=("$@") ;;
    sdist)       MODE="sdist" ;;
    -h|--help|help) usage; exit 0 ;;
    *)
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

run_prepare() {
    if [ -n "${SKIP_PREPARE}" ]; then
        log "SKIP_PREPARE set: skipping update-version / update_changelog / make_lazy_extractors"
        return
    fi

    if [ -n "${VERSION}" ]; then
        log "Updating version: channel=${CHANNEL} origin=${ORIGIN} version=${VERSION}"
        python devscripts/update-version.py -c "${CHANNEL}" -r "${ORIGIN}" "${VERSION}"
    else
        log "Updating version: channel=${CHANNEL} origin=${ORIGIN} (auto)"
        python devscripts/update-version.py -c "${CHANNEL}" -r "${ORIGIN}"
    fi

    log "Updating changelog"
    python devscripts/update_changelog.py -vv

    log "Generating lazy extractors"
    python devscripts/make_lazy_extractors.py
}

case "${MODE}" in
    unix)
        log "Installing build tooling via devscripts/install_deps.py"
        python devscripts/install_deps.py --include-group build

        run_prepare

        if command -v pandoc >/dev/null 2>&1; then
            log "pandoc present: running 'make all-extra tar' (matches CI)"
            make all-extra tar
            log "Building sdist + wheel"
            python -m build -sn .
        else
            log "pandoc missing: building only the EJS UNIX binary ('make yt-dlp-extra')"
            make yt-dlp-extra
        fi

        log "Build complete. Artifacts:"
        ls -lh yt-dlp 2>/dev/null || true
        ls -lh yt-dlp.tar.gz 2>/dev/null || true
        ls -lh dist/  2>/dev/null || true
        ;;

    pyinstaller)
        log "Installing pyinstaller dependency group via devscripts/install_deps.py"
        python devscripts/install_deps.py --include-group pyinstaller

        run_prepare

        if [ "${#JOBS[@]}" -gt 0 ]; then
            log "Running pyinstaller bundle: python -m bundle.pyinstaller ${JOBS[*]}"
            python -m bundle.pyinstaller "${JOBS[@]}"
        else
            log "Running pyinstaller bundle: python -m bundle.pyinstaller"
            python -m bundle.pyinstaller
        fi

        log "PyInstaller build complete. Artifacts:"
        ls -lh dist/ 2>/dev/null || true
        ;;

    sdist)
        if ! command -v pandoc >/dev/null 2>&1; then
            err "pandoc is required for the sdist (manpage + README.txt)"
            exit 1
        fi
        log "Installing build tooling"
        python devscripts/install_deps.py --include-group build
        run_prepare
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
