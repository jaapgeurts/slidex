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
		writeln("Parse errors");
		printAllErrors(cst.diagnostics, stderr);
		return 1;
	}

	VoidResult result = VoidResult(ok : true);

	// Pass two. Convert parse tree into abstract syntax tree.
	Result!AbstractTree ast = cst.value.buildAst();
	if (!ast.ok) {
		writeln("Ast errors");
		result.absorb(ast);
		result.ok = false;
	}

	// Pass three: resolve symbols and execute statement and build domain model
	Result!Deck deck = ast.value.resolveAst();
	if (!deck.ok) {
		writeln("Resolve errors");
		result.absorb(deck);
		result.ok = false;
	}

	if (!result.ok) {
		printAllErrors(deck.diagnostics, stderr);
		return 1;
	}

	// show the desk.
	presentDeck(args, deck.value);

	return 0;

}
