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

SourceLocation sourceLocation(pegged.peg.Position pos) {
	SourceLocation loc;
	loc.line = pos.line;
	loc.column = pos.col;
	return loc;
}

string toString(pegged.peg.Position pos) {
	return format("(%u,%u)", pos.line, pos.col);
}

void main(string[] args) {

	auto source = readText(args[1]);
	ParseTree slideDeckTree = SlidexDoc(source);

	if (!slideDeckTree.successful) {
		string msg = slideDeckTree.failMsg(
			(pegged.peg.Position pos, string left, string right, const ParseTree p) =>
				"(" ~ to!string(pos.line + 1) ~ "," ~ to!string(
					pos.col + 1) ~ ") Error: Unexpected symbol near `\x1b[31m" ~ left ~ "\x1b[1;31m" ~ right[0] ~ right[1 .. $].until('\n')
				.array.to!string ~ "\x1b[0m`.", "Ok!");
		stderr.writeln(msg);
	}

	// writeln(slideDeckTree);

	// Descend into the parse tree.

	Deck ast = parseSlidexDoc(slideDeckTree);
}

// General utility functions
private auto identity(T)(T x) => x;

string errorPrefix(ParseTree root) {
	return root.position.toString() ~ ": Error: ";
}

void errorWrongType(T)(ParseTree root, string ident, DslType value) {
	stderr.writeln(errorPrefix(root), "Value `", value.toString, "` for property `", ident, "` expected a `", T
			.stringof, "` but got a `", value.typeName, "`");

}

Deck parseSlidexDoc(ParseTree root) {
	Deck deck = new Deck();
	if (root.children.length == 1)
		parseSlideDeck(root[0], deck);

	return deck;
}

void parseSlideDeck(ParseTree root, Deck deck) {
	foreach (child; root.children) {
		switch (child.name) {
		case "SlidexDoc.Deck":
			parseDeck(child, deck);
			break;
		case "SlidexDoc.Master":
			deck.masters ~= parseMaster(child);
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

void parseDeck(ParseTree root, Deck deck) {
	foreach (child; root.children) {
		if (child.name == "SlidexDoc.DeckContent") {
			parseDeckContent(child, deck);
		}
	}
}

void parseDeckContent(ParseTree root, Deck deck) {
	foreach (child; root.children) {
		if (child.name == "SlidexDoc.ValueAssignment") {
			string ident = getAssignmentIdentifier(child);
			DslType value = getAssignmentValue(child);
			switch (ident) {
				// TODO: use static foreach to generate field assignment
			case "author":
				if (value.has!string)
					deck.author = value.get!string;
				else
					errorWrongType!string(child, ident, value);
				break;
			case "date":
				if (value.has!Date)
					deck.date = value.get!Date;
				else
					errorWrongType!Date(child, ident, value);
				break;
			default:
				// create a format and sink error function
				stderr.writeln(errorPrefix(root), "Unknown property: `", ident, "`");
				break;
			}
		}
		else {
			stderr.writeln(errorPrefix(root), "unknown node ", child.name);
		}
	}
}

Master parseMaster(ParseTree root) {
	Master master = new Master();

	master.loc = sourceLocation(root.position);

	foreach (child; root.children) {
		if (child.name == "SlidexDoc.MasterContent") {
			parseMasterContent(child, master);
		}
	}
	return master;
}

void parseMasterContent(ParseTree root, Master master) {
	foreach (child; root.children) {
		if (child.name == "SlidexDoc.Statement")
			parseStatement(child, master);
		else
			writeln("Error: Unknown parse node");
	}
}

void parseStatement(ParseTree root, Master master) {
	foreach (child; root.children) {
		switch (child.name) {
		case "SlidexDoc.PropertyDeclaration":
			// writeln("Property");
			string ident = getPropertyIdentifier(child);
			Item item = getPropertyItem(child);
			master.itemsMap[ident] = item;
			master.items ~= item;
			break;
		case "SlidexDoc.ValueAssignment":
			// writeln("Value assignment");
			string ident = getAssignmentIdentifier(child);
			DslType value = getAssignmentValue(child);
			switch (ident) {
			case "columns":
				if (value.has!int)
					master.columns = value.get!int;
				else
					errorWrongType!int(child, ident, value);
				break;
			case "rows":
				if (value.has!int)
					master.rows = value.get!int;
				else
					errorWrongType!int(child, ident, value);
				break;
			default:
				stderr.writeln(errorPrefix(root), "Unknown property: `", ident, "`");
				break;
			}
			break;
		default:
			writeln("Unknown node: ", child.name);
			break;
		}
	}
}

Rect parseRect(ParseTree root) {
	Rect rect = new Rect();

	// writeln(root[1]);

	DslType[string] args = getNamedArguments(root[1]);
	writeln("ARGS: ", args);

	foreach (k, v; args) {
		switch (k) {
		case "fill":
			if (v.has!Colour)
				rect.fill = v.get!Colour;
			else
				errorWrongType!Colour(root, "fill", v);
			break;
		default:
			stderr.writeln("Unknown argument `", k, "`");
			break;
		}
	}
	return rect;
}

Text parseText(ParseTree root) {
	Text text = new Text();

	DslType[string] namedArgs = getNamedArguments(root[1]);
	DslType[] posArgs = getPositionalArguments(root[1]);

	// possible arguments:
	// text:Text, 
	if (posArgs.length > 0 && posArgs[0].has!string) {
		text.text = posArgs[0].get!string;
	}

	return text;
}

// parsing utility functions

string getAssignmentIdentifier(ParseTree root) {
	return root.matches[0];
}

string getParamIdentifier(ParseTree root) {
	return root.matches[0];
}

DslType getAssignmentValue(ParseTree root) {
	return getValue(root[2][0]);

}

DslType getNamedParamValue(ParseTree root) {
	return getValue(root[2][0]);
}

DslType getPositionalParamValue(ParseTree root) {
	return getValue(root[0][0]);
}

DslType getValue(ParseTree root) {
	switch (root.name) {
	case "SlidexDoc.String":
		return DslType(root.matches[0]);
	case "SlidexDoc.Number":
		return DslType(root.matches[0].to!int);
	case "SlidexDoc.Colour":
		return DslType(root.matches[0].asCapitalized.array.to!Colour);
	case "SlidexDoc.Text":
		return DslType(root.matches[0]);
	case "SlidexDoc.Date":
		return DslType(Date.fromISOExtString(root.matches[0]));
	default:
		assert(false, "Type conversion for assignment value `" ~ root.name ~ "` not implemented yet");
	}

}

string getPropertyIdentifier(ParseTree root) {
	return root[0].matches[0];
}

Item getPropertyItem(ParseTree root) {
	Item item;
	// writeln(root);
	ParseTree child = root[2];
	if (child.name == "SlidexDoc.FuncCall") {
		string ident = child[0].matches[0];
		switch (ident) {
		case "rect":
			item = parseRect(child);
			break;
		case "text":
			item = parseText(child);
			break;
		default:
			assert(false, "Item creation not complete yet");
		}
	}

	// read the AT placement here.
	if (root.children.length == 4) {
		child = root[3];
		if (child.name == "SlidexDoc.Placement") {
			if(child[1][0].name == "SlidexDoc.CELL") {
				DslType[string] args = getNamedArguments(child[2]);
				GridPos pos = GridPos(args["col"].
				writeln("PLACE ARGS: ", args);
			}
		}
	}

	return item;

}

/**
  Returns a map of the named arguments.
  Root node must be SlidexDoc.ArgList
*/
DslType[string] getNamedArguments(ParseTree root) {

	// writeln("getNamedArguments(): ",root.name); 
	DslType[string] items;

	if (root[1].children.length > 0) {
		foreach (args; root[1].children) {
			if (args.name == "SlidexDoc.Argument") {
				ParseTree child = args[0];
				if (child.name == "SlidexDoc.NamedParam") {
					string ident = getParamIdentifier(child);
					DslType value = getNamedParamValue(child);
					items[ident] = value;
				}
			}
		}
	}

	return items;
}

DslType[] getPositionalArguments(ParseTree root) {

	DslType[] items;

	if (root[1].children.length > 0) {
		foreach (child; root[1][0].children) {
			if (child.name == "SlidexDoc.PositionalParam") {
				DslType value = getPositionalParamValue(child);
				items ~= value;
			}
		}
	}

	return items;
}
