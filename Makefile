PREFIX ?= $(CURDIR)/dist

.PHONY: all build install clean distclean

all: build

build:
	PREFIX="$(PREFIX)" ./build.sh

# Copy the built programs somewhere on PATH, e.g. make install PREFIX=/usr/local
install: build

clean:
	-$(MAKE) -C build/Xfoil/bin -f Makefile_gfortran clean
	-$(MAKE) -C build/Xfoil/plotlib clean

distclean:
	rm -rf build dist
