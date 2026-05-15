import std.file;
import std.stdio;

import parser;
import resolver;
import slides;
import common;

import presenter;

void printAllErrors(Diagnostic[] diagnostics, File file) {
	foreach (diag; diagnostics) {
		printError(diag, file);
	}
	file.writeln("Error: There were ", diagnostics.length, " errors and warnings.");
}

int main(string[] args) {

	string sourceFilePath = args[1];

	// Pass one. Lexical parse and build concrete syntax tree
	Result!ConcreteTree cst = parseDocument(sourceFilePath);

	if (!cst.ok) {
		printAllErrors(cst.diagnostics, stderr);
		return 1;
	}

	// Pass two. Convert parse tree into abstract syntax tree.
	Result!AbstractTree ast = cst.value.buildAst();
	if (!ast.ok) {
		printAllErrors(ast.diagnostics, stderr);
		return 2;
	}

	// Pass three: resolve symbols and execute statement and build domain model
	Result!Deck deck = ast.value.resolveAst();

	if (!deck.ok) {
		printAllErrors(deck.diagnostics, stderr);
		return 3;
	}

	// show the desk.
	presentDeck(args, deck.value);

	return 0;

}
