import std.file;
import std.stdio;
import std.path;

import dsl.parser;
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

	string filepath = args[1];
	string sourceFilePath;
	string dirpath;
	if (isFile(filepath)) {
		sourceFilePath = filepath;
		dirpath = ".";
	}
	else if (isDir(filepath)) {
		sourceFilePath = buildPath(filepath, baseName(filepath, ".slx") ~ ".slx");
		dirpath = filepath;
	}

	// Pass one. Lexical parse and build concrete syntax tree
	Result!ConcreteTree cst = parseDocument(sourceFilePath);

	if (!cst.ok) {
		writeln("Parse errors");
		printAllErrors(cst.diagnostics, stderr);
		return 1;
	}

	VoidResult result = VoidResult(ok: true);

	// Pass two. Convert parse tree into abstract syntax tree.
	Result!AbstractTree ast = cst.value.buildAst();
	result.absorb(ast);
	if (!ast.ok) {
		writeln("Ast errors");
		result.ok = false;
	}

	// Pass three: resolve symbols and execute statement and build domain model
	Result!Deck deck = ast.value.resolveAst();
	result.absorb(deck);
	if (!deck.ok) {
		writeln("Resolve errors");
		result.ok = false;
	}

	if (!result.ok) {
		printAllErrors(result.diagnostics, stderr);
		return 1;
	}

	deck.value.rootpath = dirpath;

	// show the desk.
	presentDeck(args, deck.value);

	return 0;

}
