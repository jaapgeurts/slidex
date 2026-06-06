import std.file;
import std.getopt;
import std.path;
import std.stdio;

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

	Config config;

	auto helpInfo = getopt(args,
		std.getopt.config.passThrough,
		"debug|d", "Enable debug mode.", &config.debug_,
		"verbose|v", "Print debugging output.", &config.verbose,
		"slide|s", "Start presentation at slide #", &config.slidenum,
		"monitor|m", "Show slide on monitor # or 0 to list monitors", &config.monitornum,
		"presenter|p", "Show presenter view", &config.showpresenter,
		"watch|w", "Watches input file and update changes immediately.", &config.watch,
	);
	if (helpInfo.helpWanted) {
		defaultGetoptPrinter("Slidex - DSL based slide presenter.\nUSAGE: slidex [-dhmpsvw] file\n",
			helpInfo.options);
		stderr.writeln("file\t The file name of the presentation to load.");
		return 0;
	}
	if (args.length == 1) {
		stderr.writeln("Error: file is a required argument. Use -h for help.");
		return 1;
	}

	string filepath = args[1];
	if (!exists(filepath)) {
		stderr.writeln("Error: Can't open file `", filepath, "`. No such file or directory");
		return 2;
	}

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
		return 3;
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
		return 4;
	}

	deck.value.rootpath = dirpath;

	// show the desk.
	    // writeln("Slide:  ", deck.slides[0].toString);
    // writeln("Master: ", deck.slides[0].master.toString);
    // writeln("DECK: ", deck.slides[0].master.items[0].visible);
    // open the gtk window
    SlidexApplication app = new SlidexApplication(deck.value, config);
    
	return app.run(null);

}
