import std.file;
import std.stdio;

import parser;
import resolver;
import slides;

import presenter;

int main(string[] args) {

	auto source = readText(args[1]);
	ParseResult!ConcreteTree cst = parseDocument(source);

	if (!cst.ok) {
		stderr.writeln("Error: There were ", cst.errorCount, " errors, and ", cst.warningCount, " warnings.");
		return 1;
	}

	// Descend into the parse tree.
	ParseContext ctxt = ParseContext(args[1]);
	// Pass one build concrete syntax tree
	ParseResult!(parser.Deck) ast = buildAst(ctxt, cst.value);
	if (!ast.ok) {
		stderr.writeln("Error: There were ", ast.errorCount, " errors, and ", ast.warningCount, " warnings.");
		return 1;
	}
	// Pass two: build domain model

	ParseResult!(slides.Deck) deck = resolveAst(ctxt, ast.value);

	if (!deck.ok) {
		stderr.writeln("Error: There were ", deck.errorCount, " errors, and ", deck.warningCount, " warnings.");
		return 1;
	}

	// show the desk.

	presentDeck(deck.value);

	return 0;

}
