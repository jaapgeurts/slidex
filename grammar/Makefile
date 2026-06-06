DC=ldc2

.PHONY: all

all: slxgrammar.d

slxgrammar.d: gengrammar grammar.peg
	./gengrammar

gengrammar: gengrammar.d
	dub build
