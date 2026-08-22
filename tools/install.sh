#!/usr/bin/env bash
# Build and install mcnemarOR into jamovi desktop and/or a running jamovi
# Docker container.
#
#   bash install.sh              both targets, whichever are available
#   bash install.sh desktop
#   bash install.sh docker [container]     (default container: jamovi)
#
set -euo pipefail

TARGET="${1:-both}"
CONTAINER="${2:-jamovi}"

HERE="$(cd "$(dirname "$0")/../mcnemarOR" && pwd)"
MODULE=mcnemarOR
VERSION="$(awk -F': *' '$1 == "Version" { print $2; exit }' "$HERE/DESCRIPTION")"
ARTIFACT="$HERE/${MODULE}_${VERSION}.jmo"

# ── desktop ──────────────────────────────────────────────────────────────────
install_desktop() {
  local ARCH PD APP APP_R LOG
  ARCH="$(uname -m)"
  case "$ARCH" in
    arm64)   PD="$HOME/R/.Rlib-arm" ;;
    x86_64)  PD="$HOME/R/.Rlib-x64" ;;
    *)       echo "unsupported architecture: $ARCH" >&2; return 1 ;;
  esac
  [ -d "$PD" ] || { echo "error: $PD not found" >&2; return 1; }

  APP=/Applications/jamovi.app
  APP_R="$APP/Contents/Frameworks/R.framework/Versions/Current/Resources/bin/R"
  [ -x "$APP_R" ] || { echo "error: no R inside $APP" >&2; return 1; }

  echo ">> desktop: building mcnemarOR for $ARCH using $PD"
  cd "$HERE"

  LOG="$(mktemp)"
  R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null R_LIBS_USER="$PD" \
    Rscript --vanilla -e 'jmvtools::install()' 2>&1 | tee "$LOG" | grep -vE '^\s*$' || true

  # jmvtools::install() can report errors on stdout while exiting successfully.
  # It can also claim installation succeeded after a SingletonLock failure.
  [ -f "$ARTIFACT" ] || {
    echo "error: jmvtools did not produce $ARTIFACT" >&2
    rm -f "$LOG"; return 1
  }
  if grep -q 'SingletonLock' "$LOG"; then
    echo
    echo "!! jamovi.app could not be driven (SingletonLock denied)."
    echo "!! The .jmo was still built. Install it by hand:"
    echo "!!   jamovi -> Modules -> Install from file -> $ARTIFACT"
    rm -f "$LOG"
    return 0
  fi
  if ! grep -q 'Module installed successfully' "$LOG"; then
    echo "error: jmvtools::install() did not install the module (see above)" >&2
    rm -f "$LOG"; return 1
  fi
  rm -f "$LOG"

  local MODDIR="$HOME/Library/Application Support/jamovi/modules/$MODULE"
  if [ -d "$MODDIR" ]; then
    echo ">> desktop: installed at $MODDIR"
  else
    echo "!! desktop: install reported success but $MODDIR does not exist."
    echo "!! Install $ARTIFACT by hand (Modules -> Install from file)."
    return 1
  fi
}

# ── docker ───────────────────────────────────────────────────────────────────
install_docker() {
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
    echo "!! docker: container '$CONTAINER' is not running — skipping"
    return 0
  fi

  if ! docker exec "$CONTAINER" sh -c 'command -v jmc >/dev/null 2>&1'; then
    echo "!! docker: jmc is not in the container." >&2
    echo "!! Install the jamovi compiler in the image before using this target." >&2
    return 1
  fi

  echo ">> docker: copying source into $CONTAINER"
  # --no-mac-metadata/--no-xattrs: AppleDouble ._ files otherwise land in the
  # container and jmc tries to compile them.
  tar --no-mac-metadata --no-xattrs -C "$HERE" -cf - DESCRIPTION NAMESPACE R jamovi \
    | docker exec -i "$CONTAINER" sh -c \
        'rm -rf /tmp/mcnemarOR-src && mkdir -p /tmp/mcnemarOR-src && tar -C /tmp/mcnemarOR-src -xf -'

  echo ">> docker: jmc --install"
  docker exec -i "$CONTAINER" bash -s <<'INCONTAINER'
set -euo pipefail
source /usr/lib/jamovi/bin/env.conf 2>/dev/null || true
RHOME="${R_HOME:-$(R RHOME 2>/dev/null || true)}"
[ -n "$RHOME" ] || { echo "   error: no R in the container" >&2; exit 1; }
RLIBS=/usr/lib/jamovi/modules/base/R

jmc --install /tmp/mcnemarOR-src \
    --to /usr/lib/jamovi/modules \
    --rhome "$RHOME" \
    --rlibs "$RLIBS" \
    --patch-version --skip-deps

[ -f /usr/lib/jamovi/modules/mcnemarOR/jamovi.yaml ] || {
  echo "   error: jmc did not install mcnemarOR" >&2; exit 1; }
INCONTAINER

  echo ">> docker: restarting $CONTAINER to load the module"
  docker restart "$CONTAINER" >/dev/null
  echo ">> docker: testing paired odds ratio / McNemar test"
  docker exec -i "$CONTAINER" bash -s <<'INCONTAINER'
set -euo pipefail
Rscript --vanilla -e '
    .libPaths(c(
        "/usr/lib/jamovi/modules/base/R",
        "/usr/lib/jamovi/modules/mcnemarOR/R",
        .libPaths()
    ))
    library(mcnemarOR)

    # classic paired-survey example: chi2=17.36, OR=150/86=1.744
    dat <- data.frame(
        s1 = factor(c("Approve","Approve","Disapprove","Disapprove"), c("Approve","Disapprove")),
        s2 = factor(c("Approve","Disapprove","Approve","Disapprove"), c("Approve","Disapprove")),
        n  = c(794, 150, 86, 570))

    r <- contTablesPairedOR(data=dat, rows="s1", cols="s2", counts="n")

    or <- r$odds$asDF
    stopifnot(isTRUE(all.equal(or[["v[o]"]][1], 150/86)))
    cat(sprintf("   paired odds-ratio smoke test passed (OR = %.3f)\n", or[["v[o]"]][1]))
'
INCONTAINER
  echo ">> docker: installed mcnemarOR; open Frequencies > Contingency Tables > Paired Samples (OR) to verify"
}

case "$TARGET" in
  desktop) install_desktop ;;
  docker)  install_docker ;;
  both)    install_desktop || true; echo; install_docker || true ;;
  *)       echo "usage: install.sh [desktop|docker|both] [container]" >&2; exit 1 ;;
esac
