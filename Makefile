.PHONY: all

DSRCS = $(shell find source -type f -name '*.d')

all: slidex

slidex: libsyntectbridge.so $(DSRCS)
	dub build

libsyntectbridge.so: syntectbridge/src/lib.rs
	make -C syntectbridge

source/slxgrammar.d: grammar/grammar.peg
	make -C grammar
	cp grammar/slxgrammar.d source/
