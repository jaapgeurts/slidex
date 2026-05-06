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

SourceLocation sourceLocation(const ParseContext ctxt, Position pos) {
	SourceLocation loc;
	loc.filepath = ctxt.filename;
	loc.line = pos.line;
	loc.column = pos.col;
	return loc;
}

SourceLocation sourceLocation(const ParseContext ctxt, ParseTree root) {
	return sourceLocation(ctxt, position(root));
}

string toString(Position pos, const ParseContext ctxt) {
	return format("%s:(%u,%u)", ctxt.filename, pos.line, pos.col);
}

string toString(SourceLocation loc) {
	return format("%s:(%u,%u)", loc.filepath, loc.line, loc.column);
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
	Deck ast = parseSlidexDoc(ctxt, slideDeckTree);
}

// General utility functions
private auto identity(T)(T x) => x;

string errorPrefix(const ParseContext ctxt, ParseTree root) {
	return root.position.toString(ctxt) ~ ": Error: ";
}

string errorPrefix(ParseTree root, SourceLocation loc) {
	return loc.toString() ~ ": Error: ";
}

void errorWrongType(T)(const ParseContext ctxt, ParseTree root, string ident, DslType value) {
	stderr.writeln(errorPrefix(ctxt, root), "Value `", value.toString, "` for property `", ident, "` expected a `", T
			.stringof, "` but got a `", value.typeName, "`");

}

void errorWrongType(T)(ParseTree root, string ident, LocatedVal!DslType value) {
	stderr.writeln(errorPrefix(root, value.loc), "Value `", value.toString, "` for property `", ident, "` expected a `", T
			.stringof, "` but got a `", value.typeName, "`");

}

Deck parseSlidexDoc(const ParseContext ctxt, ParseTree root) {
	Deck deck = new Deck();
	if (root.children.length == 1)
		parseSlideDeck(ctxt, root[0], deck);

	return deck;
}

void parseSlideDeck(const ParseContext ctxt, ParseTree root, Deck deck) {
	foreach (child; root.children) {
		switch (child.name) {
		case "SlidexDoc.Deck":
			parseDeck(ctxt, child, deck);
			break;
		case "SlidexDoc.Master":
			deck.masters ~= parseMaster(ctxt, child);
			break;
		case "SlidexDoc.Slide":
			writeln("Slide!");
			break;
		default:
			writeln("UNKNOWN: ", child.name);
			break;
		}
	}
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
			string ident = getAssignmentIdentifier(ctxt, child);
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

Master parseMaster(const ParseContext ctxt, ParseTree root) {
	Master master = new Master();

	master.loc = sourceLocation(ctxt, root);

	foreach (child; root.children) {
		if (child.name == "SlidexDoc.MasterContent") {
			parseMasterContent(ctxt, child, master);
		}
	}
	return master;
}

void parseMasterContent(const ParseContext ctxt, ParseTree root, Master master) {
	foreach (child; root.children) {
		if (child.name == "SlidexDoc.Statement")
			parseStatement(ctxt, child, master);
		else
			writeln("Error: Unknown parse node");
	}
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
			string ident = getAssignmentIdentifier(ctxt, child);
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

	LocatedVal!DslType[string] args = getNamedArguments(ctxt, root[1]);
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

	LocatedVal!DslType[string] namedArgs = getNamedArguments(ctxt, root[1]);
	LocatedVal!DslType[] posArgs = getPositionalArguments(ctxt, root[1]);

	// possible arguments:
	// text:Text, 
	if (posArgs.length > 0 && posArgs[0].has!string) {
		text.text = posArgs[0].get!string;
	}

	return text;
}

// parsing utility functions

string getAssignmentIdentifier(const ParseContext ctxt, ParseTree root) {
	return root.matches[0];
}

string getParamIdentifier(const ParseContext ctxt, ParseTree root) {
	return root.matches[0];
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
		return locatedDslType(root.matches[0], sourceLocation(ctxt, root));
	case "SlidexDoc.Number":
		return locatedDslType(root.matches[0].to!int, sourceLocation(ctxt, root));
	case "SlidexDoc.Colour":
		return locatedDslType(root.matches[0].asCapitalized.array.to!Colour, sourceLocation(ctxt, root));
	case "SlidexDoc.Text":
		return locatedDslType(root.matches[0], sourceLocation(ctxt, root));
	case "SlidexDoc.Date":
		return locatedDslType(Date.fromISOExtString(root.matches[0]), sourceLocation(ctxt, root));
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
				LocatedVal!DslType[string] args = getNamedArguments(ctxt,child[2]);
				CellLocation pos;

				writeln("PLACE ARGS: ", args);
				foreach(arg; args) {
				writeln("LOCS:       ",arg.loc);
				} 
			}
			else if (child[1][0].name == "SlidexDoc.BOUNDS") {
			}
		}
	}

	return item;

}

/**
  Returns a map of the named arguments.
  Root node must be SlidexDoc.ArgList
*/
LocatedVal!DslType[string] getNamedArguments(const ParseContext ctxt, ParseTree root) {

	// writeln("getNamedArguments(): ",root.name); 
	LocatedVal!DslType[string] items;

	if (root[1].children.length > 0) {
		foreach (args; root[1].children) {
			if (args.name == "SlidexDoc.Argument") {
				ParseTree child = args[0];
				if (child.name == "SlidexDoc.NamedParam") {
					string ident = getParamIdentifier(ctxt, child);
					LocatedVal!DslType value;
					value = getNamedParamValue(ctxt, child);
					Position pos = position(child);
					value.loc.line = pos.line;
					value.loc.column = pos.col;
					items[ident] = value;
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
