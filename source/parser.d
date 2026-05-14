module parser;

import std.algorithm.searching;
import std.algorithm.iteration;
import std.array;
import std.conv;
import std.datetime;
import std.format;
import std.random;
import std.range;
import std.stdio;
import std.sumtype;
import std.uni : asCapitalized;

import pegged.grammar;

import ast;
import types;

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

struct ConcreteTree {
    ParseTree root;
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

ParseResult!ConcreteTree parseDocument(string source) {

    ParseResult!ConcreteTree result = {ok: true};

    ParseTree slideDeckTree = SlidexDoc(source);

    if (!slideDeckTree.successful) {
        string msg = slideDeckTree.failMsg(
            (Position pos, string left, string right, const ParseTree p) =>
                "(" ~ to!string(pos.line + 1) ~ "," ~ to!string(
                    pos.col + 1) ~ ") Error: Unexpected symbol near `\x1b[31m" ~ left ~ "\x1b[1;31m" ~ right[0] ~ right[1 .. $].until('\n')
                .array.to!string ~ "\x1b[0m`.", "Ok!");
        stderr.writeln(msg);
        result.ok = false;
        result.errorCount++;
    }
    // writeln(slideDeckTree);

    result.value = ConcreteTree(slideDeckTree);
    return result;
}

ParseResult!Deck buildAst(const ParseContext ctxt, ConcreteTree tree) {

    ParseTree root = tree.root;
    if (root.children.length == 1)
        return parseSlideDeck(ctxt, root[0]);

    stderr.writeln(errorPrefix(ctxt, root), "Empty document!");
    return ParseResult!Deck(1, 0, false, null);
}

// TODO: everywhere return ParseResults so we can propagate errors
ParseResult!Deck parseSlideDeck(const ParseContext ctxt, ParseTree root) {
    Deck deck = new Deck();
    ParseResult!Deck result;
    result.ok = true;
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
            if (!res.ok)
                result.ok = false;
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
            string ident = getQualifiedIdentifier(ctxt, child[0]);
            LocatedVal!DslType value = getAssignmentValue(ctxt, child);
            switch (ident) {
                // TODO: use static foreach to generate field assignment
                // TODO: replace with ExtractValue
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
            ParseResult!bool res = parseMasterContent(ctxt, child, master);
            if (!res.ok) {
                result.ok = false;
                result.addIssueCount(res);
            }
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

ParseResult!Item parseItemDeclaration(PropertyDeclaration pd) {

    ParseResult!Item result = {ok: true};

    // TODO: check if this symbol is already defined in the master and refuse if so

    if (pd.ident.value is null)
        pd.ident.value = iota(26).randomSample(8).map!(x => to!char(x + 'a')).array.idup;

    if (pd.value.value.has!FuncCall) {
        FuncCall call = pd.value.value.get!FuncCall();
        switch (call.name) {
        case "rect":
            writeln("Creating rect");
            // factor out
            Rect rect;
            bool success = true;
            foreach (k, v; call.namedArgs) {
                switch (k) {
                case "fill":
                    success = extractValue!Colour(rect.fill, v.name, v.value);
                    if (!success) {
                        stderr.writeln("Invalid colour name: `", v.value.toString, "`");
                        result.ok = false;
                        result.errorCount++;
                    }
                    break;
                default:
                    stderr.writeln("Unknown argument `", k, "`");
                    result.ok = false;
                    result.errorCount++;
                    break;
                }
            }
            if (!success) {
                result.ok = false;
                result.errorCount++;
            }
            else {
                Item item = new Item(pd.ident.value);
                item.loc = pd.value.loc;
                item.layoutLocation = pd.layoutLocation;
                item.shape = rect;
                result.value = item;
            }
            break;
        case "text":
            // Deal with errors
            writeln("Creating text");
            Text text;

            // possible arguments:
            // text:Text, 
            if (call.positionalArgs.length > 0 && call.positionalArgs[0].has!string) {
                text.text = call.positionalArgs[0].get!string;
            }
            Item item = new Item(pd.ident.value);
            item.loc = pd.value.loc;
            item.layoutLocation = pd.layoutLocation;
            item.shape = text;
            result.value = item;
            break;
        case "image":
            Image image;
            if (call.positionalArgs.length > 0 && call.positionalArgs[0].has!string) {
                image.path = call.positionalArgs[0].get!string;
            }
            else if (auto val = "path" in call.namedArgs) {
                if (!extractValue!string(image.path, "path", val.value)) {
                    result.ok = false;
                    result.errorCount++;
                    break;
                }
            }
            Item item = new Item(pd.ident.value);
            item.loc = pd.value.loc;
            item.layoutLocation = pd.layoutLocation;
            item.shape = image;
            result.value = item;
            break;
        default:
            stderr.writeln(errorPrefix(call.name.loc), "Unknown declaration value: `" ~ call.name ~ "`.");
            result.ok = false;
            result.errorCount++;
            break;
        }
    }
    else {
        assert(false, "Property assignments must be Items such as Rect, Image, ...");
        result.ok = false;
        result.errorCount++;

    }
    return result;
}

ParseResult!bool parseMasterContent(const ParseContext ctxt, ParseTree root, Master master) {

    ParseResult!bool result;

    void handleValueAssignment(ValueAssignment va) {
        // assign properties

        // writeln("handleValueAssignment(): ", va.ident);
        bool success = true;
        switch (va.ident) {
            // TODO: invent better way to avoid code duplication
        case "columns":
            success = extractValue!int(master.columns, va.ident, va.value);
            break;
        case "rows":
            success = extractValue!int(master.rows, va.ident, va.value);
            break;
        case "showgrid":
            success = extractValue!bool(master.showgrid, va.ident, va.value);
            break;
        case "background":
            if (va.value.has!Colour) {
                master.background = va.value;
            }
            else if (va.value.has!FuncCall) {
                if (va.value.get!FuncCall().name == "image") {
                    master.background = va.value;
                }
                else {
                    stderr.writeln(errorPrefix(va.value.loc), "Invalid type `", va.value.toString, "`. Only color and images are allowed");
                    result.errorCount++;
                    success = false;
                }
            }
            else {
                stderr.writeln(errorPrefix(va.value.loc), "Invalid type `", va.value.toString, "`. Only color and images are allowed");
                result.errorCount++;
                success = false;
            }
            break;
        default:
            stderr.writeln(errorPrefix(va.ident.loc), "Unknown property: `", va.ident, "`");
            success = false;
            break;
        }
        if (!success) {
            result.ok = false;
            result.errorCount++;
        }
    }

    void handlePropertyDeclaration(PropertyDeclaration pd) {
        // create items
        // writeln("handlePropertyDeclaration(): ", pd);
        ParseResult!Item result = parseItemDeclaration(pd);
        if (result.ok) {
            master.items ~= result.value;
            master.itemsMap[result.value.name] = result.value;
        }
    }

    // writeln(root);

    result.ok = true;

    foreach (child; root.children) {

        // master slides currently only contain statements.
        assert(child.name == "SlidexDoc.Statement", "Master slide content is not a statement but: " ~ child
                .name);
        ParseResult!Statement stmt = parseStatement(ctxt, child);

        if (stmt.ok) {
            // writeln("parseMasterContent():", stmt);

            stmt.value.match!(
                handleValueAssignment,
                handlePropertyDeclaration,
            );
        }
    }

    return result;
}

/** 
Parses a slide node.
Pass as root: "SlidexDoc.Slide" 
*/
ParseResult!Slide parseSlide(const ParseContext ctxt, ParseTree root) {
    Slide slide = new Slide();
    slide.loc = root.sourceLocation(ctxt); // TODO preferred syntax, but dscanner doesn't like it
    // ParseResult!Slide result = ParseResult!Slide(ok : true, value: slide);
    ParseResult!Slide result = {ok: true, value: slide};
    // writeln(root);
    foreach (child; root.children) {
        switch (child.name) {
        case "SlidexDoc.MasterIdentifier":
            slide.masterName = LocatedVal!string(child[0].matches[0], child.sourceLocation(
                    ctxt));
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
            ParseResult!bool res = parseSlideContent(ctxt, child, slide);
            if (!res.ok) {
                result.ok = false;
                result.addIssueCount(res);
            }
            break;
        default:
            break;
        }
    }

    return result;
}

ParseResult!bool parseSlideContent(const ParseContext ctxt, ParseTree root, Slide slide) {

    // res.value.match!(
    // 	(Event e) {},
    // 	(ValueAssignment va) {},
    // 	(PropertyDeclaration pd) {},
    // 	(Item i) {},
    // 	);

    ParseResult!bool result;

    void handleValueAssignment(ValueAssignment va) {
        // TODO: is the value assignment a local slide field assignment?
        // LATER: currently here are no fields

        // if not, then keep it for later when the master is resolved.
        slide.assignments ~= va;
    }

    void handlePropertyDeclaration(PropertyDeclaration pd) {
        ParseResult!Item res = parseItemDeclaration(pd);

        if (res.ok) {
            slide.items ~= res.value;
            slide.itemsMap[res.value.name] = res.value;
        }
        // TODO: return parse errors
    }

    result.ok = true;

    foreach (child; root.children) {
        switch (child.name) {
        case "SlidexDoc.Event":
            assert(false, "Event parsing is not yet implemented");
            break;
        case "SlidexDoc.Statement":
            ParseResult!Statement res = parseStatement(ctxt, child);
            if (res.ok) {
                res.value.match!(
                    handleValueAssignment,
                    handlePropertyDeclaration,
                );
            }
            break;
        default:
            break;
        }
    }
    return result;
}

/**
Parses a statement node,
For root pass in "SlidexDoc.Statement"
*/
ParseResult!Statement parseStatement(const ParseContext ctxt, ParseTree root) {

    ParseResult!Statement result;

    foreach (child; root.children) {
        switch (child.name) {
        case "SlidexDoc.PropertyDeclaration":
            // writeln("->Property Declaration");
            ParseResult!PropertyDeclaration res = parsePropertyDeclaration(ctxt, child);
            if (res.ok) {
                result.value = res.value;
                result.addIssueCount(res);
                result.ok = true;
            }
            break;
        case "SlidexDoc.ValueAssignment":
            // writeln("-> Value Assignment");
            ValueAssignment assignment;
            assignment.ident = getQualifiedIdentifier(ctxt, child[0]);
            assignment.value = getAssignmentValue(ctxt, child);
            result.value = Statement(assignment);
            result.ok = true;
            break;
        default:
            result.ok = false;
            writeln("Unknown node: ", child.name);
            break;
        }
    }
    return result;
}

/** Parses a property declaration
  For root pass "SlidexDoc.PropertyDeclaration"
  */
ParseResult!PropertyDeclaration parsePropertyDeclaration(const ParseContext ctxt, ParseTree root) {
    ParseResult!PropertyDeclaration result;
    result.ok = true;

    // writeln("parsePropertyDeclaration(): ", root);

    foreach (child; root.children) {
        switch (child.name) {
        case "SlidexDoc.QualifiedIdentifier":
            // writeln("SlidexDoc.QualifiedIdentifier");
            result.value.ident = getQualifiedIdentifier(ctxt, child);
            break;
        case "SlidexDoc.FuncCall":
            // writeln("SlidexDoc.FuncCall");
            result.value.value = getValue(ctxt, child);
            break;
        case "SlidexDoc.Placement":
            // writeln("SlidexDoc.Placement");
            ParseResult!LayoutLocation res = parseAtLocation(ctxt, child);
            if (res.ok) {
                result.value.layoutLocation = res.value;
                // writeln("parse AT success: ", res.value);
            }
            else {
                // writeln("failed parse AT");
                result.ok = false;
                result.addIssueCount(res);
            }
            break;
        default:
            // unknown node;
            // stderr.writeln("INFO: Ignoring node: ", child.name);
            break;
        }
    }
    return result;
}

// parsing utility functions

/**
return the parameter named identifier.
Pass in as root : "SlidexDoc.Identifier"
*/
LocatedVal!string getParamIdentifier(
    const ParseContext ctxt, ParseTree root) {
    return LocatedVal!string(root.matches[0], root
            .sourceLocation(ctxt));
}

LocatedVal!DslType getAssignmentValue(
    const ParseContext ctxt, ParseTree root) {
    return getValue(ctxt, root[2][0]);

}

LocatedVal!DslType getNamedParamValue(
    const ParseContext ctxt, ParseTree root) {
    return getValue(ctxt, root[2][0]);
}

LocatedVal!DslType getPositionalParamValue(
    const ParseContext ctxt, ParseTree root) {
    return getValue(ctxt, root[0][0]);
}

/**
  return a property value
  for root pass in a "SlidexDoc.QualifiedIdentifier"
*/
LocatedVal!string getQualifiedIdentifier(
    const ParseContext ctxt, ParseTree root) {
    // writeln("getQualifiedIdentifier(): ", root);
    return LocatedVal!string(root.matches.join, root
            .sourceLocation(ctxt));
}

/** Returns a value
  for root pass in a "SlidexDoc.[String,Number,Colour,Text,Date,FuncCall]"
  */
LocatedVal!DslType getValue(const ParseContext ctxt, ParseTree root) {
    SourceLocation loc = root.sourceLocation(ctxt);

    enum TrueValues = ["true", "yes", "on"];

    switch (root.name) {
    case "SlidexDoc.String":
        return locatedDslType(root.matches[0], loc);
    case "SlidexDoc.Number":
        return locatedDslType(root.matches[0].to!int, loc);
    case "SlidexDoc.Colour":
        return locatedDslType(root.matches[0]
                .asCapitalized.array.to!Colour, loc);
    case "SlidexDoc.Boolean":
        return locatedDslType(TrueValues.canFind(root.matches[0]), loc);
    case "SlidexDoc.Text":
        return locatedDslType(root.matches[0], loc);
    case "SlidexDoc.Date":
        return locatedDslType(
            Date.fromISOExtString(root.matches[0]), loc);
    case "SlidexDoc.FuncCall":
        return locatedDslType(getFuncCall(ctxt, root), loc);
    case "SlidexDoc.QualifiedIdentifier":
        return locatedDslType(root.matches[0], loc);
    default:
        // writeln(root);
        assert(false, "Type conversion for assignment value `" ~ root
                .name ~ "` not implemented yet");
    }
}

FuncCall getFuncCall(const ParseContext ctxt, ParseTree root) {
    // writeln("getFuncCall(): ", root);
    return FuncCall(LocatedVal!string(root[0].matches[0], root[0].sourceLocation(ctxt)),
        getNamedArguments(ctxt, root[1]),
        getPositionalArguments(ctxt, root[1]));
}

bool extractValue(T)(ref T target, string argname, LocatedVal!DslType val) {
    if (val.value.has!T) {
        target = val.value.get!T;
        return true;
    }
    errorWrongType!T(argname, val);
    return false;
}

/**
  parse an at location 
  for root pass in "SlidexDoc.Placement"
  */
ParseResult!LayoutLocation parseAtLocation(ParseContext ctxt, ParseTree root) {
    enum LocationKind {
        Undefined,
        Cell,
        Bounds
    };
    LocationKind locKind = LocationKind.Undefined;

    NamedArg[string] args;
    foreach (child; root.children) {
        switch (child.name) {
        case "SlidexDoc.CELL":
            locKind = LocationKind.Cell;
            break;
        case "SlidexDoc.BOUNDS":
            locKind = LocationKind.Bounds;
            break;
        case "SlidexDoc.ArgList":
            args = getNamedArguments(ctxt, child);
            break;
        default:
            break;
        }
    }

    ParseResult!LayoutLocation result;
    if (locKind == LocationKind.Cell) {
        CellLocation cell;
        bool success = true;
        foreach (argname; args.keys) {
            switch (argname) {
                //dfmt off
			case "col":	    success = extractValue!int(cell.col, argname, args[argname].value); if (success) cell.col--; break;
			case "row":	    success = extractValue!int(cell.row, argname, args[argname].value); if (success) cell.row--; break;
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
        if (success) {
            result.ok = true;
            result.value = cell;
        }
    }
    else if (locKind == LocationKind.Bounds) {
        BoundsLocation bounds;
        bool success = false;
        foreach (argname; args.keys) {
            switch (argname) {
                //dfmt off
			case "x":	    success = extractValue!int(bounds.x, argname, args[argname].value); break;
			case "y":	    success = extractValue!int(bounds.y, argname, args[argname].value); break;
			case "width":	success = extractValue!int(bounds.width, argname, args[argname].value); break;
			case "height":	success = extractValue!int(bounds.height, argname, args[argname].value); break;
			case "angle":	success = extractValue!float(bounds.angle, argname, args[argname].value); break;
			//dfmt on
            default:
                result.errorCount++;
                stderr.writeln(errorPrefix(args[argname].name.loc), "Invalid argument `", argname, "`.");
                break;
            }
            if (!success)
                result.errorCount++;
        }
        // writeln("BOUNDS: ", bounds);
        if (success) {
            result.ok = true;
            result.value = bounds;
        }
    }

    return result;
}

/**
  Returns a map of the named arguments.
  Root node must be SlidexDoc.ArgList
*/
NamedArg[string] getNamedArguments(
    const ParseContext ctxt, ParseTree root) {

    // writeln("getNamedArguments(): ",root); 
    NamedArg[string] items;
    if (
        root[1].children.length > 0) {
        foreach (args; root[1].children) {
            if (args.name == "SlidexDoc.Argument") {
                ParseTree child = args[0];
                if (
                    child.name == "SlidexDoc.NamedParam") {
                    LocatedVal!string ident = getParamIdentifier(ctxt, child[0]);
                    LocatedVal!DslType value = getNamedParamValue(ctxt, child);
                    items[ident] = NamedArg(ident, value);
                }
            }
        }
    }

    return items;
}

/**
  Returns positional arguments
  pass in SlidexDoc.ArgsList
*/
LocatedVal!DslType[] getPositionalArguments(
    const ParseContext ctxt, ParseTree root) {

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
