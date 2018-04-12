package = haconiwa
CFLAGS = -std=gnu99

build:
	rake compile_all

clean:
	rake clean

configure:
	:

install:
	rake install prefix=$(CURDIR)/debian/$(package)/usr
