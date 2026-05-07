import std.algorithm.searching;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.format;
import std.stdio;
import std.sumtype;
import std.uni : asCapitalized;

import pegged.grammar;

import ast;

mixin(grammar(import("grammar.peg")));

// Wrap the parse tree so that we have access to the filename
struct ParseContext {
	string filename;
}

struct ParseResult(T) {
	/// cummulative errors and warnings
	uint errorCount;
	uint warningCount;
	// last parse result.
	bool ok;
	T value;
}

struct NamedArgsResult {
	LocatedVal!string name;
	LocatedVal!DslType value;

	alias value this;
}

SourceLocation sourceLocation(const ParseContext ctxt, Position pos) {
	SourceLocation loc;
	loc.filepath = ctxt.filename;
	loc.line = pos.line;
	loc.column = pos.col;
	return loc;
}

SourceLocation sourceLocation(ParseTree root, const ParseContext ctxt) {
	return sourceLocation(ctxt, position(root));
}

string toString(Position pos, const ParseContext ctxt) {
	return format("%s:(%u,%u)", ctxt.filename, pos.line + 1, pos.col + 1);
}

string toString(SourceLocation loc) {
	return format("%s:(%u,%u)", loc.filepath, loc.line + 1, loc.column + 1);
}

void addIssueCount(T, U)(ref ParseResult!T to, ParseResult!U from) {
	to.errorCount += from.errorCount;
	to.warningCount += from.warningCount;
}

void main(string[] args) {

	auto source = readText(args[1]);
	ParseTree slideDeckTree = SlidexDoc(source);

	if (!slideDeckTree.successful) {
		string msg = slideDeckTree.failMsg(
			(Position pos, string left, string right, const ParseTree p) =>
				"(" ~ to!string(pos.line + 1) ~ "," ~ to!string(
					pos.col + 1) ~ ") Error: Unexpected symbol near `\x1b[31m" ~ left ~ "\x1b[1;31m" ~ right[0] ~ right[1 .. $].until('\n')
				.array.to!string ~ "\x1b[0m`.", "Ok!");
		stderr.writeln(msg);
	}

	// writeln(slideDeckTree);

	// Descend into the parse tree.
	ParseContext ctxt = ParseContext(args[1]);
	ParseResult!Deck result = parseSlidexDoc(ctxt, slideDeckTree);
	if (!result.ok) {
		stderr.writeln("Error: There were ", result.errorCount, " errors, and ", result.warningCount, " warnings.");
	}
}

// General utility functions
private auto identity(T)(T x) => x;

string errorPrefix(const ParseContext ctxt, ParseTree root) {
	return root.position.toString(ctxt) ~ ": Error: ";
}

string errorPrefix(SourceLocation loc) {
	return loc.toString() ~ ": Error: ";
}

void errorWrongType(T)(const ParseContext ctxt, ParseTree root, string ident, DslType value) {
	stderr.writeln(errorPrefix(ctxt, root), "Value `", value.toString, "` for property `", ident, "` expected a `", T
			.stringof, "` but got a `", value.typeName, "`");

}

void errorWrongType(T)(string ident, LocatedVal!DslType value) {
	stderr.writeln(errorPrefix(value.loc), "Value `", value.toString, "` for property `", ident, "` expected a `", T
			.stringof, "` but got a `", value.typeName, "`");

}

ParseResult!Deck parseSlidexDoc(const ParseContext ctxt, ParseTree root) {
	if (root.children.length == 1)
		return parseSlideDeck(ctxt, root[0]);

	stderr.writeln(errorPrefix(ctxt, root), "Empty document!");
	return ParseResult!Deck(1, 0, false, null);
}

// TODO: everywhere return ParseResults so we can propagate errors
ParseResult!Deck parseSlideDeck(const ParseContext ctxt, ParseTree root) {
	Deck deck = new Deck();
	ParseResult!Deck result;
	result.value = deck;

	foreach (child; root.children) {
		switch (child.name) {
		case "SlidexDoc.Deck":
			// TODO: add ParseResult
			parseDeck(ctxt, child, deck);
			break;
		case "SlidexDoc.Master":
			ParseResult!Master res = parseMaster(ctxt, child);
			deck.masters ~= res.value;
			deck.masterMap[res.value.name] = res.value;
			result.addIssueCount(res);
			break;
		case "SlidexDoc.Slide":
			ParseResult!Slide res = parseSlide(ctxt, child);
			if (!res.ok)
				result.ok = false;
			deck.slides ~= res.value;
			deck.slideMap[res.value.name] = res.value;
			result.addIssueCount(res);
			break;
		default:
			writeln("UNKNOWN: ", child.name);
			break;
		}
	}
	return result;
}

void parseDeck(const ParseContext ctxt, ParseTree root, Deck deck) {
	foreach (child; root.children) {
		if (child.name == "SlidexDoc.DeckContent") {
			parseDeckContent(ctxt, child, deck);
		}
	}
}

void parseDeckContent(const ParseContext ctxt, ParseTree root, Deck deck) {
	foreach (child; root.children) {
		if (child.name == "SlidexDoc.ValueAssignment") {
			string ident = getAssignmentIdentifier(ctxt, child[0]);
			LocatedVal!DslType value = getAssignmentValue(ctxt, child);
			switch (ident) {
				// TODO: use static foreach to generate field assignment
			case "author":
				if (value.has!string)
					deck.author = value.get!string;
				else
					errorWrongType!string(ctxt, child, ident, value);
				break;
			case "date":
				if (value.has!Date)
					deck.date = value.get!Date;
				else
					errorWrongType!Date(ctxt, child, ident, value);
				break;
			default:
				// create a format and sink error function
				stderr.writeln(errorPrefix(ctxt, root), "Unknown property: `", ident, "`");
				break;
			}
		}
		else {
			stderr.writeln(errorPrefix(ctxt, root), "unknown node ", child.name);
		}
	}
}

ParseResult!Master parseMaster(const ParseContext ctxt, ParseTree root) {
	Master master = new Master();
	master.loc = root.sourceLocation(ctxt);

	ParseResult!Master result = {ok: true, value: master};

	assert(root.children.length == 7, "Master must contain 7 parse nodes");

	foreach (child; root.children) {
		switch (child.name) {
		case "SlidexDoc.OpeningIdentifier":
			master.name = child[0].matches[0];
			break;
		case "SlidexDoc.ClosingIdentifier":
			if (child[0].matches[0] != master.name) {
				stderr.writeln(errorPrefix(ctxt, child[0]), "Expected master name `", master.name, "` but got `", child[0]
						.matches[0], "`");
				result.errorCount++;
				result.ok = false;
			}
			break;
		case "SlidexDoc.MasterContent":
			parseMasterContent(ctxt, root[3], master);
			break;
		default:
			break;
		}
	}

	if (root[6].matches[0] != master.name) {
		stderr.writeln("Error: Closing name of master must equal master name");
		result.warningCount++;
		result.ok = false;
	}

	return result;
}

void parseMasterContent(const ParseContext ctxt, ParseTree root, Master master) {
	foreach (child; root.children) {
		if (child.name == "SlidexDoc.Statement")
			parseStatement(ctxt, child, master);
	}
}

/** 
Parses a slide node.
Pass as root: "SlidexDoc.Slide" 
*/
ParseResult!Slide parseSlide(const ParseContext ctxt, ParseTree root) {
	Slide slide = new Slide();
	slide.loc = root.sourceLocation(ctxt);

	// TODO preferred syntax, but dscanner doesn't like it
	// ParseResult!Slide result = ParseResult!Slide(ok : true, value: slide);
	ParseResult!Slide result = {ok: true, value: slide};

	writeln(root);
	foreach (child; root.children) {
		switch (child.name) {
		case "SlidexDoc.MasterIdentifier":
			slide.masterName = LocatedVal!string(child[0].matches[0], child.sourceLocation(ctxt));
			break;
		case "SlidexDoc.OpeningIdentifier":
			slide.name = child[0].matches[0];
			break;
		case "SlidexDoc.ClosingIdentifier":
			if (child[0].matches[0] != slide.name) {
				stderr.writeln(errorPrefix(ctxt, child[0]), "Expected slide name `", slide.name, "` but got `", child[0]
						.matches[0], "`");
				result.errorCount++;
				result.ok = false;
			}
			break;
		case "SlidexDoc.SlideContent":
			ParseResult!SlideContent res = parseSlideContent(ctxt, child, slide);
			res.value.match!(
				(Event e) {},
				(ValueAssignment va) {},
				(PropertyDeclaration pd) {});
			break;
		default:
			break;
		}
	}

	return result;
}

ParseResult!SlideContent parseSlideContent(const ParseContext ctxt, ParseTree root, Slide slide) {

	slide.masterName = LocatedVal!string(root[3].matches[0], root[3].sourceLocation(ctxt));
	foreach (child; root.children) {
		switch (child.name) {
		case "SlidexDoc.Event":
			assert(false, "Parse events");
			break;
		default:
			break;
		}
	}
	return ParseResult!bool(0, 0, false, false);
}

void parseStatement(const ParseContext ctxt, ParseTree root, Master master) {
	foreach (child; root.children) {
		switch (child.name) {
		case "SlidexDoc.PropertyDeclaration":
			// writeln("Property");
			string ident = getPropertyIdentifier(ctxt, child);
			Item item = getPropertyItem(ctxt, child);
			master.itemsMap[ident] = item;
			master.items ~= item;
			break;
		case "SlidexDoc.ValueAssignment":
			// writeln("Value assignment");
			string ident = getAssignmentIdentifier(ctxt, child[0]);
			DslType value = getAssignmentValue(ctxt, child);
			switch (ident) {
			case "columns":
				if (value.has!int)
					master.columns = value.get!int;
				else
					errorWrongType!int(ctxt, child, ident, value);
				break;
			case "rows":
				if (value.has!int)
					master.rows = value.get!int;
				else
					errorWrongType!int(ctxt, child, ident, value);
				break;
			default:
				stderr.writeln(errorPrefix(ctxt, root), "Unknown property: `", ident, "`");
				break;
			}
			break;
		default:
			writeln("Unknown node: ", child.name);
			break;
		}
	}
}

Rect parseRect(const ParseContext ctxt, ParseTree root) {
	Rect rect = new Rect();

	// writeln(root[1]);

	NamedArgsResult[string] args = getNamedArguments(ctxt, root[1]);
	writeln("ARGS: ", args);

	foreach (k, v; args) {
		switch (k) {
		case "fill":
			if (v.has!Colour)
				rect.fill = v.get!Colour;
			else
				errorWrongType!Colour(ctxt, root, "fill", v);
			break;
		default:
			stderr.writeln("Unknown argument `", k, "`");
			break;
		}
	}
	return rect;
}

Text parseText(const ParseContext ctxt, ParseTree root) {
	Text text = new Text();

	NamedArgsResult[string] namedArgs = getNamedArguments(ctxt, root[1]);
	LocatedVal!DslType[] posArgs = getPositionalArguments(ctxt, root[1]);

	// possible arguments:
	// text:Text, 
	if (posArgs.length > 0 && posArgs[0].has!string) {
		text.text = posArgs[0].get!string;
	}

	return text;
}

// parsing utility functions

/**
Return the assignment identifier
pass in as root: "SlidexDoc.QualifiedIdentifier"
*/
LocatedVal!string getAssignmentIdentifier(const ParseContext ctxt, ParseTree root) {
	return LocatedVal!string(root.matches[0], root.sourceLocation(ctxt));
}

/**
return the parameter named identifier.
Pass in as root : "SlidexDoc.Identifier"
*/
LocatedVal!string getParamIdentifier(const ParseContext ctxt, ParseTree root) {
	return LocatedVal!string(root.matches[0], root.sourceLocation(ctxt));
}

LocatedVal!DslType getAssignmentValue(const ParseContext ctxt, ParseTree root) {
	return getValue(ctxt, root[2][0]);

}

LocatedVal!DslType getNamedParamValue(const ParseContext ctxt, ParseTree root) {
	return getValue(ctxt, root[2][0]);
}

LocatedVal!DslType getPositionalParamValue(const ParseContext ctxt, ParseTree root) {
	return getValue(ctxt, root[0][0]);
}

LocatedVal!DslType getValue(const ParseContext ctxt, ParseTree root) {
	switch (root.name) {
	case "SlidexDoc.String":
		return locatedDslType(root.matches[0], root.sourceLocation(ctxt));
	case "SlidexDoc.Number":
		return locatedDslType(root.matches[0].to!int, root.sourceLocation(ctxt));
	case "SlidexDoc.Colour":
		return locatedDslType(root.matches[0].asCapitalized.array.to!Colour, root.sourceLocation(
				ctxt));
	case "SlidexDoc.Text":
		return locatedDslType(root.matches[0], root.sourceLocation(ctxt));
	case "SlidexDoc.Date":
		return locatedDslType(Date.fromISOExtString(root.matches[0]), root.sourceLocation(ctxt));
		// case "SlidexDoc.FuncCall":
		// 	return locatedDslType(Date.fromISOExtString(root.matches[0]), root.sourceLocation(ctxt));
	default:
		assert(false, "Type conversion for assignment value `" ~ root.name ~ "` not implemented yet");
	}

}

string getPropertyIdentifier(const ParseContext ctxt, ParseTree root) {
	return root[0].matches[0];
}

Item getPropertyItem(const ParseContext ctxt, ParseTree root) {
	Item item;
	// writeln(root);
	ParseTree child = root[2];
	if (child.name == "SlidexDoc.FuncCall") {
		string ident = child[0].matches[0];
		switch (ident) {
		case "rect":
			item = parseRect(ctxt, child);
			break;
		case "text":
			item = parseText(ctxt, child);
			break;
		default:
			assert(false, "Item creation not complete yet");
		}
	}

	// read the AT placement here.
	if (root.children.length == 4) {
		child = root[3];
		if (child.name == "SlidexDoc.Placement") {
			if (child[1][0].name == "SlidexDoc.CELL") {
				ParseResult!CellLocation res = parseCell(ctxt, child[2]);

				writeln(res.value);
				// CellLocation pos;
				// if (!validateCellArguments

				// writeln("PLACE ARGS: ", args);
				// foreach(arg; args) {
				// writeln("LOCS:       ",arg.loc);
				// } 
			}
			else if (child[1][0].name == "SlidexDoc.BOUNDS") {
			}
		}
	}

	return item;

}

/**
  Parses and validates cell content.
  Pass in a context and a parsetree node of "SlidexDoc.ArgList"
  Prints errors if any
*/
ParseResult!CellLocation parseCell(ParseContext ctxt, ParseTree root) {

	bool extractValue(T)(ref T target, string argname, LocatedVal!DslType val) {
		if (val.value.has!T) {
			target = val.value.get!T;
			return true;
		}
		errorWrongType!T(argname, val);
		return false;
	}

	// get all args
	NamedArgsResult[string] args = getNamedArguments(ctxt, root);
	// check args.
	ParseResult!CellLocation result = ParseResult!CellLocation(true);
	CellLocation cell;
	bool success = true;
	foreach (argname; args.keys) {
		switch (argname) {
			//dfmt off
		case "col":	    success = extractValue!int(cell.col, argname, args[argname].value); break;
		case "row":	    success = extractValue!int(cell.row, argname, args[argname].value); break;
		case "colspan":	success = extractValue!int(cell.colspan, argname, args[argname].value); break;
		case "rowspan":	success = extractValue!int(cell.rowspan, argname, args[argname].value); break;
		case "dx":	    success = extractValue!int(cell.dx, argname, args[argname].value); break;
		case "dy":	    success = extractValue!int(cell.dy, argname, args[argname].value); break;
		case "angle":	success = extractValue!float(cell.angle, argname, args[argname].value); break;
		//dfmt on
		default:
			result.errorCount++;
			stderr.writeln(errorPrefix(args[argname].name.loc), "Invalid argument `", argname, "`.");
			break;
		}
		if (!success)
			result.errorCount++;
	}
	result.value = cell;
	return result;
}

/**
  Returns a map of the named arguments.
  Root node must be SlidexDoc.ArgList
*/
NamedArgsResult[string] getNamedArguments(const ParseContext ctxt, ParseTree root) {

	// writeln("getNamedArguments(): ",root); 
	NamedArgsResult[string] items;
	if (root[1].children.length > 0) {
		foreach (args; root[1].children) {
			if (args.name == "SlidexDoc.Argument") {
				ParseTree child = args[0];
				if (child.name == "SlidexDoc.NamedParam") {
					LocatedVal!string ident = getParamIdentifier(ctxt, child[0]);
					LocatedVal!DslType value = getNamedParamValue(ctxt, child);
					items[ident] = NamedArgsResult(ident, value);
				}
			}
		}
	}

	return items;
}

LocatedVal!DslType[] getPositionalArguments(const ParseContext ctxt, ParseTree root) {

	LocatedVal!DslType[] items;
	if (root[1].children.length > 0) {
		foreach (child; root[1][0].children) {
			if (child.name == "SlidexDoc.PositionalParam") {
				LocatedVal!DslType value;
				value.value = getPositionalParamValue(ctxt, child);
				Position pos = position(child);
				value.loc.line = pos.line;
				value.loc.column = pos.col;
				items ~= value;
			}
		}
	}

	return items;
}
