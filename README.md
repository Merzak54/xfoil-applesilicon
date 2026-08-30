# xfoil-applesilicon

Build scripts for compiling **XFOIL 6.99** (Mark Drela / Harold Youngren, MIT) natively on
Apple Silicon Macs. No XFOIL sources are vendored here — `build.sh` downloads the official
tarball from MIT, verifies its checksum, and builds it with arm64-compatible flags.

## Prerequisites

```sh
brew install gcc                # gfortran
brew install --cask xquartz     # libX11 (XFOIL's plotting is X11-based)
```

Log out and back in once after installing XQuartz so `$DISPLAY` is set.

## Build

```sh
./build.sh                      # or: make
```

Results land in `dist/`:

```
dist/xfoil  dist/pplot  dist/pxplot  dist/share/osmap.dat  dist/xfoil-env.sh
```

## Run

```sh
source dist/xfoil-env.sh        # sets OSMAP and adds dist/ to PATH
xfoil
```

`OSMAP` must point at `osmap.dat`; XFOIL reads the Orr–Sommerfeld database through that
environment variable (`osrc/getosfile.c`) and silently loses the `e^n` transition database
without it.

Overrides: `PREFIX`, `FC`, `CC`, `FFLAGS`, `CFLAGS`, `XFOIL_URL`, `XFOIL_LDFLAGS`.

## What needed patching, and why

The 6.99 makefiles date from f77-era Unix and do not build as shipped with Homebrew
gfortran on arm64:

| Stock setting | Problem on Apple Silicon | Fix |
| --- | --- | --- |
| `-m64` in `plotlib/config.make` | rejected for `arm64-apple-darwin` | dropped |
| `-I/usr/X11/include`, `-L/usr/X11R6/lib` | XQuartz installs under `/opt/X11` | X11 prefix detected at build time |
| `FC = f77`, plain `-O` | gfortran ≥ 10 turns argument rank/type mismatches into errors (`plgrid`, `getvar`, `pollab`, …) | `-std=legacy -fallow-argument-mismatch` |
| C compiled with default `-std` | `Xwin2.c` and `getosfile.c` use K&R function definitions | `-std=gnu89` |
| `INSTALLCMD = install -s` | stripping invalidates the ad-hoc code signature of an arm64 binary | `install -m 0755` |
| `BINDIR = /home/codes/bin/` | non-existent path | `PREFIX`, default `dist/` |

Everything is applied as `make` variable overrides plus one drop-in
`plotlib/config.make` (`patches/plotlib-config.make.arm64`) — the XFOIL sources themselves
are never edited, so the build stays reproducible against the pristine MIT tarball.

Double precision (`-fdefault-real-8`) is used throughout, matching upstream's
`Makefile_gfortran` default; the Xplot11 library must be built with the same flag or the
link silently mixes real sizes.

## Building manually

```sh
cd Xfoil/plotlib
cp /path/to/patches/plotlib-config.make.arm64 config.make
make libPlt.a

cd ../bin
make -f Makefile_gfortran \
  FC=gfortran CC=clang \
  FFLAGS="-O2 -fdefault-real-8 -std=legacy -fallow-argument-mismatch" \
  FFLOPT="-O2 -fdefault-real-8 -std=legacy -fallow-argument-mismatch" \
  CFLAGS="-O2 -DUNDERSCORE -std=gnu89 -I/opt/X11/include" \
  PLTOBJ=../plotlib/libPlt.a PLTLIB="-L/opt/X11/lib -lX11" \
  BINDIR=$PWD INSTALLCMD="install -m 0755" all
```

## Troubleshooting

* `ld: unknown option` / linker errors with Xcode 15+ and Homebrew GCC:
  `XFOIL_LDFLAGS=-Wl,-ld_classic ./build.sh`
* No plot window: XQuartz must be running and `$DISPLAY` set. XFOIL itself is usable
  without plotting (`PLOP` → `G` toggles graphics off).

## Licensing

XFOIL and Xplot11 are GPL-licensed; this repository contains only build tooling and
downloads the sources at build time from
<https://web.mit.edu/drela/Public/web/xfoil/>.
