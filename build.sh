#!/usr/bin/env bash
#
# Build XFOIL 6.99 on Apple Silicon (macOS arm64).
#
# No XFOIL sources live in this repo: the official 6.99 tarball is downloaded
# from MIT and built in place with arm64-friendly compiler flags.
#
# Requirements (see README.md):
#   brew install gcc            # provides gfortran
#   brew install --cask xquartz # provides libX11 in /opt/X11
#
set -euo pipefail

XFOIL_VERSION="6.99"
XFOIL_TARBALL="xfoil${XFOIL_VERSION}.tgz"
XFOIL_URL="${XFOIL_URL:-https://web.mit.edu/drela/Public/web/xfoil/${XFOIL_TARBALL}}"
XFOIL_SHA256="5c0250643f52ce0e75d7338ae2504ce7907f2d49a30f921826717b8ac12ebe40"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${ROOT}/build"
SRCDIR="${WORK}/Xfoil"
PREFIX="${PREFIX:-${ROOT}/dist}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------
# Toolchain discovery
# --------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "this script targets macOS; on Linux use the stock Makefiles"
if [ "$(uname -m)" != "arm64" ]; then
  echo "warning: not running on arm64 ($(uname -m)); the flags below are still valid but untested here" >&2
fi

BREW_PREFIX="${BREW_PREFIX:-$(brew --prefix 2>/dev/null || echo /opt/homebrew)}"

FC="${FC:-$(command -v gfortran || true)}"
[ -n "${FC}" ] || die "gfortran not found. Install it with:  brew install gcc"

CC="${CC:-clang}"

# X11 headers/libs: XQuartz first, then a Homebrew libx11.
X11_PREFIX=""
for cand in /opt/X11 "${BREW_PREFIX}"; do
  if [ -f "${cand}/include/X11/Xlib.h" ]; then X11_PREFIX="${cand}"; break; fi
done
[ -n "${X11_PREFIX}" ] || die "X11 headers not found. Install XQuartz with:  brew install --cask xquartz"

log "gfortran : ${FC} ($(${FC} -dumpversion))"
log "C compiler: ${CC}"
log "X11      : ${X11_PREFIX}"
log "prefix   : ${PREFIX}"

# --------------------------------------------------------------------------
# Flags
#
#   -fdefault-real-8            XFOIL's supported double-precision build
#   -std=legacy                 accept the F77-isms modern gfortran rejects
#   -fallow-argument-mismatch   gfortran >= 10 makes rank/type mismatches errors
#   no -m64                     clang/gfortran reject it on arm64
#   -std=gnu89 for C            Xwin2.c and getosfile.c use K&R definitions
# --------------------------------------------------------------------------
FFLAGS="${FFLAGS:--O2 -fdefault-real-8 -std=legacy -fallow-argument-mismatch}"
CFLAGS_C="${CFLAGS:--O2 -DUNDERSCORE -std=gnu89 -Wno-implicit-function-declaration -I${X11_PREFIX}/include}"
LINKLIB="-L${X11_PREFIX}/lib -lX11 ${XFOIL_LDFLAGS:-}"

# --------------------------------------------------------------------------
# Fetch
# --------------------------------------------------------------------------
mkdir -p "${WORK}"
if [ ! -f "${WORK}/${XFOIL_TARBALL}" ]; then
  log "downloading ${XFOIL_URL}"
  curl -fsSL -o "${WORK}/${XFOIL_TARBALL}" "${XFOIL_URL}"
fi

actual="$(shasum -a 256 "${WORK}/${XFOIL_TARBALL}" | awk '{print $1}')"
[ "${actual}" = "${XFOIL_SHA256}" ] || die "checksum mismatch for ${XFOIL_TARBALL}: got ${actual}"

if [ ! -d "${SRCDIR}" ]; then
  log "extracting ${XFOIL_TARBALL}"
  tar xzf "${WORK}/${XFOIL_TARBALL}" -C "${WORK}"
fi

# --------------------------------------------------------------------------
# Xplot11 (plotting library XFOIL links against)
# --------------------------------------------------------------------------
log "building Xplot11"
cp "${ROOT}/patches/plotlib-config.make.arm64" "${SRCDIR}/plotlib/config.make"
make -C "${SRCDIR}/plotlib" \
  PLTLIB=libPlt.a \
  FC="${FC}" CC="${CC}" \
  FFLAGS="${FFLAGS}" CFLAGS="${CFLAGS_C}" \
  LINKLIB="${LINKLIB}" \
  libPlt.a

# --------------------------------------------------------------------------
# xfoil / pplot / pxplot
#
# bin/Makefile_gfortran has no config file, so every arm64-relevant variable is
# overridden on the command line. INSTALLCMD drops the stock `-s`: stripping an
# arm64 binary invalidates its ad-hoc code signature.
# --------------------------------------------------------------------------
log "building xfoil, pplot, pxplot"
mkdir -p "${PREFIX}"
make -C "${SRCDIR}/bin" -f Makefile_gfortran \
  FC="${FC}" CC="${CC}" \
  FFLAGS="${FFLAGS}" FFLOPT="${FFLAGS}" \
  CFLAGS="${CFLAGS_C}" \
  PLTOBJ="../plotlib/libPlt.a" \
  PLTLIB="${LINKLIB}" \
  BINDIR="${PREFIX}" \
  INSTALLCMD="install -m 0755" \
  all

# --------------------------------------------------------------------------
# Runtime data: xfoil reads the Orr-Sommerfeld database through $OSMAP
# --------------------------------------------------------------------------
install -d "${PREFIX}/share"
install -m 0644 "${SRCDIR}/orrs/osmap.dat" "${PREFIX}/share/osmap.dat"

cat > "${PREFIX}/xfoil-env.sh" <<EOF
# source this before running xfoil from ${PREFIX}
export OSMAP="${PREFIX}/share/osmap.dat"
export PATH="${PREFIX}:\$PATH"
EOF

log "done: ${PREFIX}/xfoil"
log "run:  source ${PREFIX}/xfoil-env.sh && xfoil"
