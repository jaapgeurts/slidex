module parser;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.format;
import std.meta;
import std.random;
import std.range;
import std.stdio;
import std.sumtype;
import std.typecons;
import std.uni : asCapitalized;

import pegged.grammar;

import ast;
import resolver;
import common;

mixin(grammar(import("grammar.peg")));

alias LocatedResult(T) = Result!(LocatedVal!T);

alias SlidexTypes = AliasSeq!(int, float, bool, string, Date, RgbColour, RichText, Image, Rect, Text, Seconds, Percent, Centimeter);

alias SlidexType = TaggedUnion!SlidexTypes;

alias EvalResult = Result!SlidexType;

/////////////////////////
// Helper functions
SourceLocation sourceLocation(Position pos, string filepath) {
    SourceLocation loc;
    loc.filepath = filepath;
    loc.line = pos.line;
    loc.column = pos.col;
    return loc;
}

SourceLocation sourceLocation(ParseTree root, string filepath) {
    return sourceLocation(position(root), filepath);
}

Result!Unit stringToUnit(string str, SourceLocation loc) {
    Result!Unit result;
    switch (str) {
        // dfmt off
        case "s":  result.value = Unit.Seconds; result.ok = true; break;
        case "fr": result.value = Unit.Fraction; result.ok = true; break;
        case "cm": result.value = Unit.Centimeter; result.ok = true; break;
        case "%":  result.value = Unit.Percent; result.ok = true; break;
        // dfmt on
    default:
        result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidUnit, Severity.Error, loc, "Invalid unit name `" ~ str ~ "` conversion not implemented.");
    }
    return result;
}

RgbColour namedColourToRgb(NamedColour colour) {
    final switch (colour) {
    case NamedColour.Red:
        return RgbColour(0xff, 0x00, 0x00);
    case NamedColour.Green:
        return RgbColour(0x00, 0xff, 0x00);
    case NamedColour.Blue:
        return RgbColour(0x00, 0x00, 0xff);
    case NamedColour.Cyan:
        return RgbColour(0x00, 0xff, 0xff);
    case NamedColour.Magenta:
        return RgbColour(0xff, 0x00, 0xff);
    case NamedColour.Yellow:
        return RgbColour(0xff, 0xff, 0x00);
    case NamedColour.White:
        return RgbColour(0xff, 0xff, 0xff);
    case NamedColour.Black:
        return RgbColour(0x00, 0x00, 0x00);
    }
}

private Diagnostic createInvalidTypeDiag(LocatedVal!DslType val, string expectedType) {
    return Diagnostic(DiagnosticKind.InvalidType,
        Severity.Error, val.loc, "Invalid value `" ~ val.value.toVariant.toString() ~ "`. Expected a " ~ expectedType ~ " but got " ~ val
            .value.typeName() ~ ".");
}

///////////////////////
// Parser

public Result!ConcreteTree parseDocument(string sourceFilePath) {

    Result!ConcreteTree result;
    size_t error_index;

    string addErrorToResult(Position pos, string left, string right, const ParseTree p) {
        error_index = pos.index;
        Diagnostic diag;
        diag.kind = DiagnosticKind.ParseError;
        diag.severity = Severity.Error;
        diag.loc = SourceLocation(sourceFilePath, pos.line, pos.col);
        diag.message = "Unexpected symbol near `\x1b[31m" ~ left ~ "\x1b[1;31m" ~ right[0] ~ right[1 .. $].until('\n')
            .array.to!string ~ "\x1b[0m`.";
        result.diagnostics ~= diag;
        return diag.message;
    }

    auto source = readText(sourceFilePath);

    ParseTree slideDeckTree = SlidexDoc(source);

    if (!slideDeckTree.successful) {
        // add error to detected failed node (this may not be the actuall error due to backtracking)
        slideDeckTree.failMsg(&addErrorToResult, null);

        if (error_index != slideDeckTree.failEnd) {
            // the detected error is not as far as the parser was able reach
            size_t charsbefore = slideDeckTree.failEnd - 10;
            if (charsbefore < 0)
                charsbefore = 0;
            size_t charsafter = slideDeckTree.failEnd + 10;
            if (charsafter > slideDeckTree.input.length)
                charsafter = slideDeckTree.input.length;
            string left = slideDeckTree.input[charsbefore .. slideDeckTree.failEnd];
            string right = slideDeckTree.input[slideDeckTree.failEnd .. charsafter];
            addErrorToResult(position(slideDeckTree.input[0 .. slideDeckTree.failEnd]), left, right, slideDeckTree);
        }
        return result;
    }

    if (slideDeckTree.children.length == 0) {
        Diagnostic diag = Diagnostic(DiagnosticKind.ParseError, Severity.Error, slideDeckTree.sourceLocation(
                sourceFilePath), "Empty file.");
        result.diagnostics ~= diag;
        return result;
    }

    result.ok = true;
    result.value = ConcreteTree(slideDeckTree, sourceFilePath);

    return result;
}

struct ConcreteTree {
    ParseTree concreteRoot;
    string sourceFilePath;

    Result!AbstractTree buildAst() {

        Result!AbstractTree result;
        result.ok = true;

        SlidexAstBuilder builder = SlidexAstBuilder(sourceFilePath);

        Result!Deck res = builder.buildSlideDeck(concreteRoot);

        result.absorb(res);

        // writeln("deck:   " , res.value);
        // writeln("slides: " , res.value.slides);
        result.value = AbstractTree(res.value, sourceFilePath);

        return result;
    }
}

struct SlidexAstBuilder {

    string sourceFilePath;

private:

    // TODO: everywhere return Results so we can propagate errors
    Result!Deck buildSlideDeck(ParseTree root) {

        Result!Deck result = Result!Deck(ok: true);
        Deck deck = new Deck();

        // find the slide deck.
        bool found = false;
        foreach (child; root.children) {
            if (child.name == "SlidexDoc.SlideDeck") {
                found = true;
                root = child;
                break;
            }
        }
        if (!found) {
            result.ok = false;
            return result;
        }

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Deck":
                VoidResult res = parseDeck(child, deck);
                result.absorb(res);
                break;
            case "SlidexDoc.Master":
                Result!Master res = parseMaster(child);
                deck.masters ~= res.value;
                deck.masterMap[res.value.name] = res.value;
                result.absorb(res);
                break;
            case "SlidexDoc.Slide":
                Result!Slide res = parseSlide(child);
                result.absorb(res);
                deck.slides ~= res.value;
                deck.slideMap[res.value.name] = res.value;
                break;
            default:
                assert(false, "Unknown Node: " ~ child.name);
                break;
            }
        }
        result.value = deck;
        return result;
    }

    VoidResult parseDeck(ParseTree root, Deck deck) {
        VoidResult result = VoidResult(ok: true);
        foreach (child; root.children) {
            if (child.name == "SlidexDoc.DeckContent") {
                VoidResult res = parseDeckContent(child, deck);
                result.absorb(res);
            }
        }
        return result;
    }

    VoidResult parseDeckContent(ParseTree root, Deck deck) {
        VoidResult result = VoidResult(ok: true);
        foreach (child; root.children) {
            if (child.name == "SlidexDoc.ValueAssignment") {
                LocatedVal!string ident = getQualifiedIdentifier(child[0]);
                LocatedVal!DslType val = getValue(getAssignmentValueNode(child));
                switch (ident.value) {
                    // TODO: use static foreach to generate field assignment
                    // TODO: replace with ExtractValue
                case "author":
                    EvalResult res = evalValue(val);
                    result.absorb(res);
                    if (res.ok && res.value.has!string)
                        deck.author = res.value.get!string;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val, "string");

                    break;
                case "date":
                    EvalResult res = evalValue(val);
                    result.absorb(res);
                    if (res.ok && res.value.has!Date)
                        deck.date = res.value.get!Date;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val, "date");
                    break;
                default:
                    // create a format and sink error function
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, ident.loc,
                        "No such property `" ~ ident.value ~ "`");
                    result.ok = false;
                    break;
                }
            }
            else {
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        return result;
    }

    Result!Master parseMaster(ParseTree root) {
        Master master = new Master();

        Result!Master result = Result!Master(ok: true, value: master);

        assert(root.children.length == 7, "Master must contain 7 parse nodes");

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.OpeningIdentifier":
                master.name = child[0].matches[0];
                break;
            case "SlidexDoc.ClosingIdentifier":
                string foundname = child[0].matches[0];
                if (foundname != master.name) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.NameMismatch, Severity.Warning, child[0].sourceLocation(sourceFilePath),
                        "Expected master name `" ~ master.name ~ "` but got `" ~ foundname ~ "`");
                }
                break;
            case "SlidexDoc.MasterContent":
                VoidResult res = parseMasterContent(child, master);
                result.absorb(res);
                break;
            case "SlidexDoc.MASTER":
            case "SlidexDoc.BEGIN":
            case "SlidexDoc.END":
            case "SlidexDoc.COLON":
                // ignore this node 
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
                break;
            }
        }

        return result;
    }

    Result!Item parseItemDeclaration(PropertyDeclaration pd) {

        Result!Item result = Result!Item(ok: true);

        // TODO: check if this symbol is already defined in the master and refuse if so

        if (pd.ident.value is null)
            pd.ident.value = iota(26).randomSample(8).map!(x => to!char(x + 'a')).array.idup;

        Item item = new Item(pd.ident.value);
        item.loc = pd.value.loc;
        item.layoutLocation = pd.layoutLocation;

        EvalResult val = evalValue(pd.value);
        result.absorb(val);
        if (val.ok) {
            if (val.value.has!Rect)
                item.shape = val.value.get!Rect;
            else if (val.value.has!Text)
                item.shape = val.value.get!Text;
            else if (val.value.has!Image)
                item.shape = val.value.get!Image;
            else
                result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, pd.value.loc, "Property elements must be presentation elements such as Text, Image, ...");

            result.value = item;

        }
        return result;
    }

    VoidResult parseMasterContent(ParseTree root, Master master) {

        VoidResult handleValueAssignment(ValueAssignment va) {
            // assign properties
            VoidResult r1 = VoidResult(ok: true);
            // writeln("handleValueAssignment(): ", va.ident);
            switch (va.ident) {
                // TODO: detect duplicate assignments
            case "columns":
                EvalResult res = evalValue(va.value);
                r1.absorb(res);
                if (res.ok && res.value.has!int)
                    master.columns = res.value.get!int;
                else
                    r1.diagnostics ~= createInvalidTypeDiag(va.value, "int");
                break;
            case "rows":
                EvalResult res = evalValue(va.value);
                r1.absorb(res);
                if (res.ok && res.value.has!int)
                    master.rows = res.value.get!int;
                else
                    r1.diagnostics ~= createInvalidTypeDiag(va.value, "int");
                break;
            case "background":
                // assert(false, "Rgb Parsing not implemented");
                EvalResult res = evalValue(va.value);
                r1.absorb(res);
                if (res.ok && res.value.has!RgbColour)
                    master.background = res.value.get!RgbColour;
                else if (res.ok && res.value.has!Image)
                    master.background = res.value.get!Image;
                else
                    r1.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, va.value.loc, "Invalid type `" ~
                            va.value.typeName ~ "`. Expected colour or image but found `" ~ va.value.get!FuncCall()
                                .name ~ "`");
                break;
            default:
                r1.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, va.value.loc, "No such property `" ~
                        va.ident ~ "`.");
                r1.ok = false;
                break;
            }
            return r1;
        }

        VoidResult handlePropertyDeclaration(PropertyDeclaration pd) {
            VoidResult r1;
            // create items
            //  writeln("handlePropertyDeclaration(): ", pd);
            if (pd.ident in master.itemsMap) {
                r1.diagnostics ~= Diagnostic(DiagnosticKind.DuplicateDeclaration, Severity.Error, pd.ident.loc, "Name `" ~ pd
                        .ident ~ "` already used.");
                return r1;
            }
            Result!Item res = parseItemDeclaration(pd);
            r1.absorb(res);
            if (res.ok) {
                r1.ok = true;
                master.items ~= res.value;
                master.itemsMap[res.value.name] = res.value;
            }
            return r1;
        }

        // writeln(root);
        VoidResult result = VoidResult(ok: true);

        foreach (child; root.children) {

            // master slides only supports statements.
            assert(child.name == "SlidexDoc.Statement", "Master slide content is not a statement but: " ~
                    child.name);
            Result!Statement stmt = parseStatement(child);
            result.absorb(stmt);
            if (stmt.ok) {
                // writeln("parseMasterContent():", stmt);

                VoidResult res = stmt.value.match!(
                    handleValueAssignment,
                    handlePropertyDeclaration,
                );
                result.absorb(res);
            }
        }

        return result;
    }

    /** 
Parses a slide node.
Pass as root: "SlidexDoc.Slide" 
*/
    Result!Slide parseSlide(ParseTree root) {

        Result!Slide result = Result!Slide(ok: true);
        Slide slide = new Slide();

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.MasterIdentifier":
                slide.masterName = LocatedVal!string(child[0].matches[0], child.sourceLocation(
                        sourceFilePath));
                break;
            case "SlidexDoc.OpeningIdentifier":
                slide.name = child[0].matches[0];
                break;
            case "SlidexDoc.ClosingIdentifier":
                string foundname = child[0].matches[0];
                if (foundname != slide.name) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.NameMismatch, Severity.Warning, child[0].sourceLocation(sourceFilePath), "Expected slide name `" ~ slide
                            .name ~ "` but got `" ~ child[0].matches[0] ~ "`");
                    result.ok = false;
                }
                break;
            case "SlidexDoc.SlideContent":
                VoidResult res = parseSlideContent(child, slide);
                result.absorb(res);
                break;
            default:
                break;
            }
        }
        result.value = slide;
        return result;
    }

    VoidResult parseSlideContent(ParseTree root, Slide slide) {

        VoidResult handleValueAssignment(ValueAssignment va) {
            // TODO: is the value assignment a local slide field assignment?
            // LATER: currently slides have no fields so can't assign anything either.
            // so keep it for later when the master is resolved.

            slide.assignments ~= va;
            return VoidResult(ok: true);
        }

        VoidResult handlePropertyDeclaration(PropertyDeclaration pd) {
            VoidResult result;
            Result!Item res = parseItemDeclaration(pd);

            result.absorb(res);
            if (res.ok) {
                result.ok = true;
                slide.items ~= res.value;
                slide.itemsMap[res.value.name] = res.value;
            }
            return result;
        }

        VoidResult result = VoidResult(ok: true);

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Event":
                assert(false, "Event parsing is not yet implemented");
                break;
            case "SlidexDoc.Statement":
                Result!Statement r1 = parseStatement(child);
                result.absorb(r1);
                if (r1.ok) {
                    VoidResult r2 = r1.value.match!(
                        handleValueAssignment,
                        handlePropertyDeclaration,
                    );
                    result.absorb(r2);
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
    Result!Statement parseStatement(ParseTree root) {

        Result!Statement result = Result!Statement(ok: true);

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.PropertyDeclaration":
                // writeln("->Property Declaration");
                Result!PropertyDeclaration res = parsePropertyDeclaration(child);
                result.absorb(res).ifSome((v) { result.value = v; });
                break;
            case "SlidexDoc.ValueAssignment":
                // writeln("-> Value Assignment");
                ValueAssignment assignment;
                assignment.ident = getQualifiedIdentifier(child[0]);
                assignment.value = getValue(getAssignmentValueNode(child));
                result.value = Statement(assignment);
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
                break;
            }
        }
        return result;
    }

    /** Parses a property declaration
  For root pass "SlidexDoc.PropertyDeclaration"
  */
    Result!PropertyDeclaration parsePropertyDeclaration(ParseTree root) {
        Result!PropertyDeclaration result = Result!PropertyDeclaration(ok: true);

        // writeln("parsePropertyDeclaration(): ", root);

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.QualifiedIdentifier":
                // writeln("SlidexDoc.QualifiedIdentifier");
                result.value.ident = getQualifiedIdentifier(child);
                break;
            case "SlidexDoc.FuncCall":
                // writeln("SlidexDoc.FuncCall");
                result.value.value = getValue(child);
                break;
            case "SlidexDoc.Placement":
                // writeln("SlidexDoc.Placement");
                Result!LayoutLocation res = parseAtLocation(child);
                result.absorb(res).ifSome((ll) {
                    result.value.layoutLocation = ll;
                });
                break;
            case "SlidexDoc.COLON":
                // ignore these nodes
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
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
    LocatedVal!string getParamIdentifier(ParseTree root) {
        return LocatedVal!string(root.matches[0], root
                .sourceLocation(sourceFilePath));
    }

    ParseTree getAssignmentValueNode(ParseTree root) {
        return root[2][0];
    }

    ParseTree getNamedParamValueNode(ParseTree root) {
        return root[2][0];
    }

    ParseTree getPositionalParamValueNode(ParseTree root) {
        return root[0][0];
    }

    /**
  return a property value
  for root pass in a "SlidexDoc.QualifiedIdentifier"
*/
    LocatedVal!string getQualifiedIdentifier(ParseTree root) {
        // writeln("getQualifiedIdentifier(): ", root);
        return LocatedVal!string(root.matches.join, root
                .sourceLocation(sourceFilePath));
    }

    /** Returns a value
  for root pass in a "SlidexDoc.[String,Number,Colour,RichText,Date,FuncCall]"
  */
    LocatedVal!DslType getValue(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);

        enum TrueValues = ["true", "yes", "on"];

        switch (root.name) {
        case "SlidexDoc.String":
            return locatedDslType(root.matches[0], loc);
        case "SlidexDoc.Number":
            return locatedDslType(root.matches[0].to!int, loc);
        case "SlidexDoc.Quantity":
            // TODO: currently can't distinguish between int and float values
            return locatedDslType!Quantity(getQuantity(root), loc);
        case "SlidexDoc.NamedColour":
            // fixed color value.
            // TODO: handle RGB value
            return locatedDslType(root.matches[0].asCapitalized.array.to!NamedColour, loc);
        case "SlidexDoc.Boolean":
            return locatedDslType(TrueValues.canFind(root.matches[0]), loc);
        case "SlidexDoc.RichText":
            return locatedDslType(RichText(root.matches[0]), loc);
        case "SlidexDoc.Date":
            return locatedDslType(
                Date.fromISOExtString(root.matches[0]), loc);
        case "SlidexDoc.FuncCall":
            return locatedDslType(getFuncCall(root), loc);
        case "SlidexDoc.QualifiedIdentifier":
            return locatedDslType(root.matches[0], loc);
        default:
            // writeln(root);
            assert(false, "Type conversion for assignment value `" ~ root
                    .name ~ "` not implemented yet");
        }
    }

    /** returns a FunCall from a Value
     * valueNode is a ParseTree node to the value
     */
    FuncCall getFuncCall(ParseTree root) {
        // writeln("getFuncCall(): ", root);
        return FuncCall(LocatedVal!string(root[0].matches[0], root[0].sourceLocation(
                sourceFilePath)),
            getNamedArguments(root[1]),
            getPositionalArguments(root[1]));
    }

    /**
  parse an at location 
  for root pass in "SlidexDoc.Placement"
  */
    Result!LayoutLocation parseAtLocation(ParseTree root) {
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
                /// TODO: can i use eval here?
                break;
            case "SlidexDoc.ArgList":
                args = getNamedArguments(child);
                break;
            default:
                break;
            }
        }

        Result!LayoutLocation result = Result!LayoutLocation(ok: true);
        if (locKind == LocationKind.Cell) {
            CellLocation cell;
            foreach (argname, val; args) {
                switch (argname) {
                case "col":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        cell.col = res.value.get!int - 1;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "row":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        cell.row = res.value.get!int - 1;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "colspan":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        cell.colspan = res.value.get!int;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "rowspan":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        cell.rowspan = res.value.get!int;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "dx":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        cell.dx = res.value.get!int;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "dy":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        cell.dy = res.value.get!int;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "angle":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!float)
                        cell.angle = res.value.get!float;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "float");
                    break;
                default:
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, args[argname]
                            .name.loc, "Unknown argument name `" ~ argname ~ "`");
                    result.ok = false;
                    break;
                }
            }
            if (result.ok) {
                result.value = cell;
            }
        }
        else if (locKind == LocationKind.Bounds) {
            BoundsLocation bounds;
            foreach (argname, val; args) {
                switch (argname) {
                case "x":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        bounds.x = res.value.get!int;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "y":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        bounds.y = res.value.get!int;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "width":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        bounds.width = res.value.get!int;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "height":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!int)
                        bounds.height = res.value.get!int;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                    break;
                case "angle":
                    EvalResult res = evalValue(val.value);
                    result.absorb(res);
                    if (res.ok && res.value.has!float)
                        bounds.angle = res.value.get!float;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "float");
                    break;
                default:
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, args[argname]
                            .name.loc, "Unknown argument name `" ~ argname ~ "`");
                    result.ok = false;
                    break;
                }
            }
            // writeln("BOUNDS: ", bounds);
            if (result.ok) {
                result.value = bounds;
            }
        }

        return result;
    }

    /**
  Returns a map of the named arguments.
  Root node must be SlidexDoc.ArgList
*/
    NamedArg[string] getNamedArguments(ParseTree root) {

        // writeln("getNamedArguments(): ",root); 
        NamedArg[string] items;
        if (
            root[1].children.length > 0) {
            foreach (args; root[1].children) {
                if (args.name == "SlidexDoc.Argument") {
                    ParseTree child = args[0];
                    if (
                        child.name == "SlidexDoc.NamedParam") {
                        LocatedVal!string ident = getParamIdentifier(child[0]);
                        LocatedVal!DslType value = getValue(getNamedParamValueNode(child));
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
    LocatedVal!DslType[] getPositionalArguments(ParseTree root) {
        LocatedVal!DslType[] items;
        if (root[1].children.length > 0) {
            foreach (child; root[1].children) {
                // TODO: fix this. Not pretty
                if (child.name == "SlidexDoc.Argument")
                    child = child[0];
                if (child.name == "SlidexDoc.PositionalParam") {
                    LocatedVal!DslType value;
                    value.value = getValue(getPositionalParamValueNode(child));
                    Position pos = position(child);
                    value.loc.line = pos.line;
                    value.loc.column = pos.col;
                    items ~= value;
                }
            }
        }

        return items;
    }

    Quantity getQuantity(ParseTree root) {
        Quantity qty;
        // TODO: currently can't distinguish between int and float values
        qty.value = LocatedVal!float(root[0].matches[0].to!float,
            root[0].sourceLocation(sourceFilePath));
        if (root.children.length == 2) {
            // unit present
            SourceLocation unitloc = root[1].sourceLocation(sourceFilePath);
            qty.unit = LocatedVal!string(root[1].matches[0], unitloc);
        }
        return qty;

    }
}

/// Evalation functions

EvalResult evalValue(LocatedVal!DslType val) {
    if (val.value.has!int) {
        return EvalResult(ok: true, value: SlidexType(val.value.get!int));
    }
    else if (val.value.has!float) {
        return EvalResult(ok: true, value: SlidexType(val.value.get!float));
    }
    else if (val.value.has!bool) {
        return EvalResult(ok: true, value: SlidexType(val.value.get!bool));
    }
    if (val.value.has!string) {
        return EvalResult(ok: true, value: SlidexType(val.value.get!string));
    }
    else if (val.value.has!NamedColour) {
        return EvalResult(ok: true, value: SlidexType(
                namedColourToRgb(val.value.get!NamedColour)));
    }
    else if (val.value.has!Quantity) {
        return evalQuantity(val.value.get!Quantity);
    }
    else if (val.value.has!Date) {
        // TODO: handle date parsing exception 
        return EvalResult(ok: true, value: SlidexType(val.value.get!Date));
    }
    else if (val.value.has!RichText) {
        return EvalResult(ok: true, value: SlidexType(val.value.get!RichText));
    }
    else if (val.value.has!FuncCall) {
        FuncCall v = val.value.get!FuncCall;
        switch (v.name) {
        case "rgb":
            return evalColour(v);
        case "rect":
            return evalRect(v);
        case "text":
            return evalText(v);
        case "image":
            return evalImage(v);
        default: // TODO: replace with error
            assert(false, "unimplemented function: " ~ v.name);
        }
    }

    assert(false, "Unreachable");
}

EvalResult evalColour(FuncCall rgb) {
    // TODO: value reading should use eval functions
    EvalResult result;
    if (rgb.namedArgs.length > 0) {
        result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, rgb.name.loc, "rgb() colours do not accept named arugments. Expected rgb(r,g,b) or rgb(\"#12ab7f\")");
        result.ok = false;
    }
    else if (rgb.positionalArgs.length == 3) {
        // parse components
        bool success = true;
        RgbColour colour;
        for (size_t i = 0; i < 3; i++) {
            if (!rgb.positionalArgs[i].value.has!Quantity) {
                result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, rgb
                        .positionalArgs[i].loc, "Invalid value `" ~ rgb.positionalArgs[i].value.toVariant()
                        .toString() ~ "` Expected a number but got `" ~ rgb
                        .positionalArgs[i].value.typeName ~ "`");
                success = false;
            }
            // else if (rgb.positionalArgs[i].value.Quantity!int().value < 0 || rgb.positionalArgs[i].value.get!int > 255) {
            //     result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, rgb
            //             .positionalArgs[i].loc, "Invalid value `" ~ rgb.positionalArgs[i].value.toVariant()
            //             .toString() ~ "`. Color values must be between 0 and 255.");
            //     success = false;
            // }
    else {
                colour[i] = cast(ubyte) rgb.positionalArgs[i].value
                    .get!Quantity.value.value;
            }
        }

        if (success) {
            result.value = SlidexType(colour);
            result.ok = true;
        }
    }
    else if (rgb.positionalArgs.length == 1 && rgb.positionalArgs[0].value.has!string) {
        // parse string
        string hexval = rgb.positionalArgs[0].value.get!string;
        bool success = false;
        RgbColour colour;
        if (hexval[0] == '#') {
            try {
                ubyte[] triplet = hexval[1 .. $].fromHex;
                if (triplet.length == 3) {
                    for (size_t i = 0; i < 3; i++) {
                        colour[i] = triplet[i];
                    }
                    success = true;
                }
            }
            catch (Exception e) {
                writeln("failed: ", e);
                success = false;
            }
        }
        if (success) {
            result.ok = true;
            result.value = SlidexType(colour);
        }
        else {
            result.diagnostics ~= Diagnostic(DiagnosticKind.ParseError, Severity.Error, rgb.positionalArgs[0].loc, "Invalid hex colour value: Expected \"#rrggbb\" but got `" ~ hexval ~ "`.");
        }
    }
    else {
        writeln("VAL: ", rgb.positionalArgs);
        result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, rgb.name.loc, "Invalid number of arguments `" ~ rgb
                .positionalArgs.length.to!string ~ "` Expected rgb(r,g,b) or rgb(\"0x12ab7f\")");
    }
    return result;
}

EvalResult evalQuantity(Quantity v) {
    if (v.unit.value == null)
        return EvalResult(ok: true, value: SlidexType(cast(int) v.value.value));
    else if (v.unit == "s")
        return EvalResult(ok: true, value: SlidexType(Seconds(cast(int) v.value.value)));
    else if (v.unit == "%")
        return EvalResult(ok: true, value: SlidexType(Percent(cast(ubyte) v.value.value)));
    else if (v.unit == "cm")
        return EvalResult(ok: true, value: SlidexType(Centimeter(cast(int) v.value.value)));

    EvalResult result = EvalResult(ok: false);
    result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidUnit, Severity.Error, v.unit.loc, "Invalid unit `" ~ v.unit.value ~ "`.");
    return result;
}

EvalResult evalRect(FuncCall func) {
    EvalResult result;
    if (NamedArg* arg = "fill" in func.namedArgs) {
        EvalResult res = evalValue(arg.value);
        result.absorb(res);
        Rect rect;
        if (res.ok && res.value.has!RgbColour) {
            rect.fill = res.value.get!RgbColour;
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(arg.value, "rect");
        }
        result.ok = true;
        result.value = SlidexType(rect);
    }
    return result;
}

EvalResult evalText(FuncCall func) {
    EvalResult result;
    Text text;
    if (func.positionalArgs.length == 1) {
        LocatedVal!DslType val = func.positionalArgs[0];
        EvalResult res = evalValue(val);
        result.absorb(res);
        if (res.ok && res.value.has!RichText) {
            text.content = cast(string) res.value.get!RichText;
            result.ok = true;
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(val, "richtext");
        }
    }
    if (func.namedArgs.length > 0) {
        // TODO: must consume all args or fail.
        // TODO: generalize arg reading
        if (NamedArg* arg = "colour" in func.namedArgs) {
            EvalResult res = evalValue(arg.value);
            result.absorb(res);
            if (res.ok && res.value.has!RgbColour) {
                text.colour = res.value.get!RgbColour;
            }
            else {
                result.diagnostics ~= createInvalidTypeDiag(arg.value, "colour");
            }
        }
        if (NamedArg* arg = "size" in func.namedArgs) {
            EvalResult res = evalValue(arg.value);
            result.absorb(res);
            if (res.ok && res.value.has!int) {
                text.size = res.value.get!int;
            }
            else {
                result.diagnostics ~= createInvalidTypeDiag(arg.value, "int");
            }
        }
    }
    result.value = SlidexType(text);
    return result;
}

EvalResult evalImage(FuncCall func) {
    EvalResult result;
    // TODO: these functions need error reporting
    Image image;
    if (func.positionalArgs.length == 1) {
        LocatedVal!DslType val = func.positionalArgs[0];
        EvalResult res = evalValue(val);
        result.absorb(res);
        if (res.ok && res.value.has!string) {
            image.path = res.value.get!string;
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(val, "image");
        }
        result.ok = true;
        result.value = SlidexType(image);
    }
    else if (NamedArg* arg = "path" in func.namedArgs) {
        EvalResult res = evalValue(arg.value);
        result.absorb(res);
        if (res.ok && res.value.has!string) {
            image.path = res.value.get!string;
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(arg.value, "image");
        }
        result.ok = true;
        result.value = SlidexType(image);
    }
    return result;
}
