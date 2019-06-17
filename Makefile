package = haconiwa
CFLAGS = -std=gnu99
PREFIX = $(CURDIR)/debian/$(package)/usr

build:
	rake compile_all

clean:
	rake clean

configure:
	:

install:
	rake install prefix=$(PREFIX)
