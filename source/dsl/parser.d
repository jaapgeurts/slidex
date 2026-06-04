module dsl.parser;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.uni; // tolower
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

import dsl.ast;
import common;
import resolver;
import types;
import richtext.parser;
import core.internal.abort;

import slxgrammar;

// see tools/gengrammar.d
// mixin(grammar(import("grammar.peg")));

alias LocatedResult(T) = Result!(LocatedVal!T);

alias SlidexTypes = AliasSeq!(int, float, bool, string, Date, RgbColour, RichText, Image, Rect, Text, Video, Seconds, Percent, Centimeter, Fraction, Pixel, CellAlignment, SlidexArray);

alias SlidexType = TaggedUnion!SlidexTypes;

alias EvalResult = Result!SlidexType;

struct SlidexArray {
    LocatedVal!(SlidexType)[] items;
}

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

CellAlignment alignmentToCellAlignment(Alignment alignment) {
    final switch (alignment) {
    case Alignment.TopLeft:
        return CellAlignment.TopLeft;
    case Alignment.TopCenter:
        return CellAlignment.TopCenter;
    case Alignment.TopRight:
        return CellAlignment.TopRight;
    case Alignment.CenterLeft:
        return CellAlignment.CenterLeft;
    case Alignment.Center:
        return CellAlignment.Center;
    case Alignment.CenterRight:
        return CellAlignment.CenterRight;
    case Alignment.BottomLeft:
        return CellAlignment.BottomLeft;
    case Alignment.BottomCenter:
        return CellAlignment.BottomCenter;
    case Alignment.BottomRight:
        return CellAlignment.BottomRight;
    }
    assert(false, "unreachable");
}

// TODO: should print the read value string, instead of a reconstructed string
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
        diag.message = "Unexpected symbol near " ~ left ~ "\x1b[1;31m";
        if (right.length > 0)
            diag.message ~= right[0] ~ "\x1b[0m";
        if (right.length > 1)
            diag.message ~= right[1 .. $].until('\n').array.to!string;
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

public:

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
                result.absorb(res);
                if (res.ok) {
                    deck.masters ~= res.value;
                    deck.masterMap[res.value.name] = res.value;
                }
                break;
            case "SlidexDoc.Slide":
                Result!Slide res = parseSlide(child);
                result.absorb(res);
                if (res.ok) {
                    deck.slides ~= res.value;
                    deck.slideMap[res.value.name] = res.value;
                }
                break;
            default:
                assert(false, "Unknown Node: " ~ child.name);
            }
        }
        result.value = deck;
        return result;
    }

private:

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
                Result!ValueAssignment res = parseValueAssignment(child);
                result.absorb(res);
                if (res.ok) {
                    ValueAssignment va = res.value;

                    switch (va.ident.value) {
                        // TODO: use static foreach to generate field assignment
                        // TODO: replace with ExtractValue
                    case "author":
                        EvalResult r1 = evalValue(va.value);
                        result.absorb(r1);
                        if (r1.ok && r1.value.has!string)
                            deck.author = r1.value.get!string;
                        else
                            result.diagnostics ~= createInvalidTypeDiag(va.value, "string");

                        break;
                    case "date":
                        EvalResult r1 = evalValue(va.value);
                        result.absorb(r1);
                        if (r1.ok && r1.value.has!Date)
                            deck.date = r1.value.get!Date;
                        else
                            result.diagnostics ~= createInvalidTypeDiag(va.value, "date");
                        break;
                    default:
                        // create a format and sink error function
                        result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, va.ident.loc,
                            "No such property `" ~ va.ident.value ~ "`");
                        result.ok = false;
                        break;
                    }
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

        Result!Master result = Result!Master(ok: true);

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.OpeningIdentifier":
                master.name = parseIdentifier(child[0]);
                break;
            case "SlidexDoc.ClosingIdentifier":
                string foundname = child[0].matches[0];
                if (foundname != master.name) {
                    result.ok = false;
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
            }
        }
        result.value = master;

        return result;
    }

    // this is eval.
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
            else if (val.value.has!Video)
                item.shape = val.value.get!Video;
            else {
                result.ok = false;

                result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, pd.value.loc, "Property elements must be presentation elements such as Text, Image, ...");
            }

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
                if (res.ok && res.value.has!int) {
                    master.columns = res.value.get!int;
                }
                else if (res.ok && res.value.has!SlidexArray) {
                    master.columns = res.value.get!SlidexArray;
                }
                else {
                    res.ok = false;
                    r1.diagnostics ~= createInvalidTypeDiag(va.value, "int or quantity[]");
                }
                break;
            case "rows":
                EvalResult res = evalValue(va.value);
                r1.absorb(res);
                if (res.ok && res.value.has!int) {
                    master.rows = res.value.get!int;
                }
                else if (res.ok && res.value.has!SlidexArray) {
                    master.rows = res.value.get!SlidexArray;
                }
                else {
                    r1.ok = false;
                    r1.diagnostics ~= createInvalidTypeDiag(va.value, "int");
                }
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
            VoidResult r1 = VoidResult(ok: true);
            // create items
            // writeln("handlePropertyDeclaration(): ", pd);
            if (pd.ident in master.itemsMap) {
                r1.diagnostics ~= Diagnostic(DiagnosticKind.DuplicateDeclaration, Severity.Error, pd.ident.loc, "Name `" ~ pd
                        .ident ~ "` already used.");
                r1.ok = false;
                return r1;
            }
            Result!Item res = parseItemDeclaration(pd);
            r1.absorb(res);
            if (res.ok) {
                master.items ~= res.value;
                master.itemsMap[res.value.name] = res.value;
            }
            return r1;
        }

        // writeln(root);
        VoidResult result = VoidResult(ok: true);

        foreach (child; root.children) {

            switch (child.name) {
            case "SlidexDoc.Statement":
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
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
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
                // TODO: do i need to store a located value here?
                slide.masterName = LocatedVal!string(parseIdentifier(child[0]), child.sourceLocation(
                        sourceFilePath));
                break;
            case "SlidexDoc.OpeningIdentifier":
                slide.name = parseIdentifier(child[0]);
                break;
            case "SlidexDoc.ClosingIdentifier":
                string foundname = parseIdentifier(child[0]);
                if (foundname != slide.name) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.NameMismatch, Severity.Warning, child[0].sourceLocation(sourceFilePath), "Expected slide name `" ~ slide
                            .name ~ "` but got `" ~ parseIdentifier(child[0]) ~ "`");
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
                Result!ValueAssignment res = parseValueAssignment(child);
                result.absorb(res).ifSome((v) { result.value = v; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
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
                result.value.ident = parseQualifiedIdentifier(child);
                break;
            case "SlidexDoc.FuncCall":
                Result!(LocatedVal!DslType) res = parseFuncCall(child);
                result.absorb(res).ifSome((v) { result.value.value = v; });
                break;
            case "SlidexDoc.Placement":
                // writeln("SlidexDoc.Placement");
                Result!LayoutLocation res = parsePlacement(child);
                result.absorb(res).ifSome((ll) {
                    result.value.layoutLocation = ll;
                });
                break;
            case "SlidexDoc.WsComment":
            case "SlidexDoc.COLON":
                // ignore these nodes
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        return result;
    }

    Result!ValueAssignment parseValueAssignment(ParseTree root) {
        Result!ValueAssignment result;

        ValueAssignment assignment;

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.QualifiedIdentifier":
                assignment.ident = parseQualifiedIdentifier(child);
                break;
            case "SlidexDoc.Value":
                Result!(LocatedVal!DslType) res = parseValue(child);
                result.absorb(res).ifSome((v) {
                    assignment.value = v;
                    result.ok = true;
                });
                break;
            case "SlidexDoc.EQUAL":
            case "SlidexDoc.WsComment":
                // ignore
                break;
            default:
                assert(false, "unknown node: " ~ child.name);
            }
        }
        result.value = assignment;
        return result;
    }

    /** Returns a value
  for root pass in a "SlidexDoc.Value"
  */
    Result!(LocatedVal!DslType) parseValue(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Identifier":
                return Result!(LocatedVal!DslType)(ok: true, value: locatedDslType(parseIdentifier(child), loc));
            case "SlidexDoc.String":
                return parseString(child);
            case "SlidexDoc.Number":
                return parseNumber(child);
            case "SlidexDoc.Quantity":
                return parseQuantity(child);
            case "SlidexDoc.NamedColour":
                return parseNamedColour(child);
            case "SlidexDoc.Alignment":
                return parseAlignment(child);
            case "SlidexDoc.Boolean":
                return parseBoolean(child);
            case "SlidexDoc.RichText":
                return parseRichText(child);
            case "SlidexDoc.Date":
                return parseDate(child);
            case "SlidexDoc.FuncCall":
                return parseFuncCall(child);
            case "SlidexDoc.Array":
                return parseArray(child);
            default:
                assert(false, "Value conversion for value `" ~ child.name ~ "` not implemented yet");
            }
        }
        assert(false, "Unreachable");
    }

    Result!(LocatedVal!DslType) parseString(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        return Result!(LocatedVal!DslType)(ok: true, value: locatedDslType(root.matches[0], loc));
    }

    Result!(LocatedVal!DslType) parseNumber(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        return Result!(LocatedVal!DslType)(ok: true, value: locatedDslType(
                root.matches.join()
                .to!int, loc));
    }

    Result!(LocatedVal!string) parseUnit(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        return Result!(LocatedVal!string)(ok: true, value: LocatedVal!string(root.matches[0], loc));
    }

    Result!(LocatedVal!DslType) parseQuantity(ParseTree root) {
        // TODO: currently can't distinguish between int and float values
        Result!(LocatedVal!DslType) result;
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        Quantity qty;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Number":
                Result!(LocatedVal!DslType) res = parseNumber(child);
                result.absorb(res).ifSome((n) {
                    qty.value = LocatedVal!float(n.value
                        .get!int
                        .to!float, n.loc);
                    result.ok = true;
                });
                break;
            case "SlidexDoc.Unit":
                Result!(LocatedVal!string) res = parseUnit(child);
                result.absorb(res).ifSome((s) { qty.unit = s; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = locatedDslType(qty, loc);
        return result;
    }

    Result!(LocatedVal!DslType) parseNamedColour(ParseTree root) {
        // fixed color value.
        // TODO: handle RGB value
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        return Result!(LocatedVal!DslType)(ok: true, value: locatedDslType(
                root.matches[0].asCapitalized.array.to!NamedColour, loc));
    }

    Result!(LocatedVal!DslType) parseAlignment(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        static immutable AlignmentValues = [
            "topleft": Alignment.TopLeft,
            "topcenter": Alignment.TopCenter,
            "topright": Alignment.TopRight,
            "centerleft": Alignment.CenterLeft,
            "center": Alignment.Center,
            "centerright": Alignment.CenterRight,
            "bottomleft": Alignment.BottomLeft,
            "bottomcenter": Alignment.BottomCenter,
            "bottomright": Alignment.BottomRight
        ];
        Alignment t = AlignmentValues[root.matches[0].toLower.array.to!string];
        return Result!(LocatedVal!DslType)(ok: true, value: locatedDslType(t, loc));
    }

    Result!(LocatedVal!DslType) parseBoolean(ParseTree root) {
        enum TrueValues = ["true", "yes", "on"];
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        return Result!(LocatedVal!DslType)(ok: true, value: locatedDslType(
                TrueValues.canFind(root.matches[0]), loc));
    }

    Result!(LocatedVal!DslType) parseRichText(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        RichTextASTBuilder builder = RichTextASTBuilder(this.sourceFilePath);
        // writeln("RichText CST: ", root);
        Result!RichText res = builder.buildRichText(root);
        Result!(LocatedVal!DslType) result;
        result.absorb(res).ifSome((v) {
            writeln("RichText AST: ", v);
            result.value = locatedDslType(v, loc);
            result.ok = true;
        });
        return result;
    }

    Result!(LocatedVal!DslType) parseDate(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);
        return Result!(LocatedVal!DslType)(ok: true, value: locatedDslType(
                Date.fromISOExtString(root.matches[0]), loc));
    }

    Result!(LocatedVal!DslType) parseFuncCall(ParseTree root) {
        Result!(LocatedVal!DslType) result;
        SourceLocation loc = root.sourceLocation(sourceFilePath);

        FuncCall call;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Identifier":
                call.name = parseIdentifier(child);
                break;
            case "SlidexDoc.ArgList":
                Result!ArgList res = parseArgList(child);
                result.absorb(res).ifSome((a) {
                    call.arguments = a;
                    result.ok = true;
                });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = locatedDslType(call, loc);
        return result;
    }

    Result!(LocatedVal!DslType) parseArray(ParseTree root) {

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.ArrayValues":
                return parseArrayValues(child);
                break;
            case "SlidexDoc.LSQUARE":
            case "SlidexDoc.RSQUARE":
            case "SlidexDoc.WsComment":
                //ignore
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        assert(false, "unreachable");
    }

    Result!(LocatedVal!DslType) parseArrayValues(ParseTree root) {
        SourceLocation loc = root.sourceLocation(sourceFilePath);

        Result!(LocatedVal!DslType) result = Result!(LocatedVal!DslType)(ok: true);
        DslArray arr;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Value":
                Result!(LocatedVal!DslType) res = parseValue(child);
                result.absorb(res).ifSome((v) { arr.items ~= v; });
                break;
            case "SlidexDoc.COMMA":
            case "SlidexDoc.WsComment":
                //ignore
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = locatedDslType(arr, loc);
        return result;
    }

    /**
    return a property value
    for root pass in a "SlidexDoc.QualifiedIdentifier"
    */
    LocatedVal!string parseQualifiedIdentifier(ParseTree root) {
        // writeln("getQualifiedIdentifier(): ", root);
        return LocatedVal!string(root.matches.join, root.sourceLocation(sourceFilePath));
    }

    LocatedVal!string parseIdentifier(ParseTree root) {
        return LocatedVal!string(root.matches[0], root.sourceLocation(sourceFilePath));
    }

    /**
  Returns a map of the named arguments.
  Root node must be SlidexDoc.ArgList
*/

    Result!ArgList parseArgList(ParseTree root) {

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Args":
                return parseArgs(child);
            case "SlidexDoc.WsComment":
            case "SlidexDoc.LPAREN":
            case "SlidexDoc.RPAREN":
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        return Result!ArgList(ok: true); // empty list
    }

    /** parses a "SlidexDoc.Args" */
    Result!ArgList parseArgs(ParseTree root) {
        Result!ArgList result = Result!ArgList(ok: true);
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Argument":
                Result!(SumType!(NamedArg, LocatedVal!DslType)) res = parseArgument(child);
                result.absorb(res);
                if (res.ok) {
                    res.value.match!(
                        (NamedArg na) { result.value.namedArgs[na.name] = na; },
                        (LocatedVal!DslType pa) {
                        result.value.positionalArgs ~= pa;
                    });
                }
                break;
            case "SlidexDoc.WsComment":
            case "SlidexDoc.COMMA":
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        return result;
    }

    Result!(SumType!(NamedArg, LocatedVal!DslType)) parseArgument(ParseTree root) {
        Result!(SumType!(NamedArg, LocatedVal!DslType)) result;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.NamedArg":
                Result!NamedArg res = parseNamedArg(child);
                result.absorb(res).ifSome((v) {
                    result.value = v;
                    result.ok = true;
                });
                break;
            case "SlidexDoc.PositionalArg":
                Result!(LocatedVal!DslType) res = parsePositionalArg(child);
                result.absorb(res).ifSome((v) {
                    result.value = v;
                    result.ok = true;
                });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        return result;
    }

    Result!NamedArg parseNamedArg(ParseTree root) {
        Result!NamedArg result;
        NamedArg arg;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Identifier":
                arg.name = parseIdentifier(child);
                break;
            case "SlidexDoc.Value":
                Result!(LocatedVal!DslType) res = parseValue(child);
                result.absorb(res).ifSome((v) { arg.value = v; result.ok = true; });
                break;
            case "SlidexDoc.EQUAL":
            case "SlidexDoc.WsComment":
                // ignore
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = arg;
        return result;
    }

    Result!(LocatedVal!DslType) parsePositionalArg(ParseTree root) {
        Result!(LocatedVal!DslType) result;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Value":
                return parseValue(child);
            case "SlidexDoc.WsComment":
                // ignore
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        return result;
    }

    /**
  parse an at location 
  for root pass in "SlidexDoc.Placement"
  */
    Result!LayoutLocation parsePlacement(ParseTree root) {
        enum LocationKind {
            Undefined,
            Cell,
            Bounds
        }

        LocationKind locKind = LocationKind.Undefined;

        Result!LayoutLocation result = Result!LayoutLocation(ok: true);

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
                Result!ArgList res = parseArgList(child);
                result.absorb(res);
                if (res.ok) {
                    if (res.value.positionalArgs.length > 0) {
                        assert(false, "Positional args not supported for cell location/bounds");
                    }
                    args = res.value.namedArgs;
                }
                break;
            case "SlidexDoc.WsComment":
            case "SlidexDoc.AT":
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }

        if (locKind == LocationKind.Cell) {
            CellLocation cell;
            foreach (argname, val; args) {
                EvalResult res = evalValue(val.value);
                result.absorb(res);
                if (!res.ok)
                    continue;
                switch (argname) {
                case "col":
                    if (res.value.has!int)
                        cell.col = res.value.get!int - 1;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "row":
                    if (res.value.has!int)
                        cell.row = res.value.get!int - 1;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "colspan":
                    if (res.value.has!int)
                        cell.colspan = res.value.get!int;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "rowspan":
                    if (res.value.has!int)
                        cell.rowspan = res.value.get!int;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "dx":
                    if (res.value.has!int)
                        cell.dx = res.value.get!int;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "dy":
                    if (res.value.has!int)
                        cell.dy = res.value.get!int;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "angle":
                    if (res.value.has!int)
                        cell.angle = res.value.get!int * 0.0174532925;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "align":
                    if (res.value.has!CellAlignment)
                        cell.alignment = res.value.get!CellAlignment;
                    else
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "call alignment");
                    break;
                default:
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, args[argname]
                            .name.loc, "1. Unknown argument name `" ~ argname ~ "`");
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
                EvalResult res = evalValue(val.value);
                result.absorb(res);
                if (!res.ok)
                    continue;
                switch (argname) {
                case "x":
                    if (res.value.has!int)
                        bounds.x = res.value.get!int;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "y":
                    if (res.value.has!int)
                        bounds.y = res.value.get!int;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "width":
                    if (res.value.has!int)
                        bounds.width = res.value.get!int;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "height":
                    if (res.value.has!int)
                        bounds.height = res.value.get!int;
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                case "angle":
                    if (res.value.has!int) {
                        writeln("specced angle");
                        bounds.angle = res.value.get!int * 0.0174532925;
                    }
                    else {
                        result.diagnostics ~= createInvalidTypeDiag(val.value, "int");
                        result.ok = false;
                    }
                    break;
                default:
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, args[argname]
                            .name.loc, "2. Unknown argument name `" ~ argname ~ "`");
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
}

/// TODO: move to separate file
/// Evalation functions
/** Evaluates a DslType value and returns a SlidexType value
*/
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
    else if (val.value.has!Alignment) {
        return EvalResult(ok: true, value: SlidexType(
                alignmentToCellAlignment(val.value.get!Alignment)));
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
        case "video":
            return evalVideo(v);
        default: // TODO: replace with error
            assert(false, "unimplemented function: " ~ v.name);
        }
    }
    else if (val.value.has!DslArray) {
        EvalResult result = EvalResult(ok: true);
        DslArray fromArray = val.value.get!DslArray;
        SlidexArray toArray;
        foreach (LocatedVal!DslType item; fromArray.items) {
            EvalResult res = evalValue(item);
            result.absorb(res);
            toArray.items ~= LocatedVal!SlidexType(res.value, item.loc);
        }
        result.value = SlidexType(toArray);
        return result;
    }

    assert(false, "Evaluation of `" ~ val.value.typeName ~ "` not implemented");
}

EvalResult evalColour(FuncCall rgb) {
    // TODO: value reading should use eval functions
    EvalResult result;
    if (rgb.arguments.namedArgs.length > 0) {
        result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, rgb.name.loc, "rgb() colours do not accept named arugments. Expected rgb(r,g,b) or rgb(\"#12ab7f\")");
        result.ok = false;
    }
    else if (rgb.arguments.positionalArgs.length == 3) {
        // parse components
        bool success = true;
        RgbColour colour;
        for (size_t i = 0; i < 3; i++) {
            if (!rgb.arguments.positionalArgs[i].value.has!Quantity) {
                result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, rgb
                        .arguments
                        .positionalArgs[i].loc, "Invalid value `" ~ rgb.arguments.positionalArgs[i].value.toVariant()
                        .toString() ~ "` Expected a number but got `" ~ rgb.arguments
                        .positionalArgs[i].value.typeName ~ "`");
                success = false;
            }
            // else if (rgb.arguments.positionalArgs[i].value.Quantity!int().value < 0 || rgb.arguments.positionalArgs[i].value.get!int > 255) {
            //     result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, rgb
            //             .positionalArgs[i].loc, "Invalid value `" ~ rgb.arguments.positionalArgs[i].value.toVariant()
            //             .toString() ~ "`. Color values must be between 0 and 255.");
            //     success = false;
            // }
    else {
                colour[i] = cast(ubyte) rgb.arguments.positionalArgs[i].value
                    .get!Quantity.value.value;
            }
        }

        if (success) {
            result.value = SlidexType(colour);
            result.ok = true;
        }
    }
    else if (rgb.arguments.positionalArgs.length == 1 && rgb.arguments
        .positionalArgs[0].value.has!string) {
        // parse string
        string hexval = rgb.arguments.positionalArgs[0].value.get!string;
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
            result.diagnostics ~= Diagnostic(DiagnosticKind.ParseError, Severity.Error, rgb.arguments.positionalArgs[0].loc, "Invalid hex colour value: Expected \"#rrggbb\" but got `" ~ hexval ~ "`.");
        }
    }
    else {
        writeln("VAL: ", rgb.arguments.positionalArgs);
        result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, rgb.name.loc, "Invalid number of arguments `" ~ rgb
                .arguments
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
    else if (v.unit == "px")
        return EvalResult(ok: true, value: SlidexType(Pixel(cast(int) v.value.value)));
    else if (v.unit == "fr")
        return EvalResult(ok: true, value: SlidexType(Fraction(cast(ubyte) v.value.value)));

    EvalResult result = EvalResult(ok: false);
    result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidUnit, Severity.Error, v.unit.loc, "Invalid unit `" ~ v
            .unit.value ~ "`.");
    return result;
}

EvalResult evalRect(FuncCall func) {
    EvalResult result;
    if (NamedArg* arg = "fill" in func.arguments.namedArgs) {
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
    EvalResult result = EvalResult(ok: true);
    Text text;
    if (func.arguments.positionalArgs.length == 1) {
        LocatedVal!DslType val = func.arguments.positionalArgs[0];
        EvalResult res = evalValue(val);
        result.absorb(res);
        if (res.ok && res.value.has!RichText) {
            text.content = res.value.get!RichText;
        }
        else {
            result.ok = false;
            result.diagnostics ~= createInvalidTypeDiag(val, "richtext");
        }
    }
    if (func.arguments.namedArgs.length > 0) {
        // TODO: must consume all args or fail.
        // TODO: generalize arg reading
        if (NamedArg* arg = "colour" in func.arguments.namedArgs) {
            EvalResult res = evalValue(arg.value);
            result.absorb(res);
            if (res.ok && res.value.has!RgbColour) {
                text.colour = res.value.get!RgbColour;
            }
            else {
                result.ok = false;
                result.diagnostics ~= createInvalidTypeDiag(arg.value, "colour");
            }
        }
        if (NamedArg* arg = "size" in func.arguments.namedArgs) {
            EvalResult res = evalValue(arg.value);
            result.absorb(res);
            if (res.ok && res.value.has!int) {
                text.size = res.value.get!int;
            }
            else {
                result.ok = false;
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
    if (func.arguments.positionalArgs.length == 1) {
        LocatedVal!DslType val = func.arguments.positionalArgs[0];
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
    else if (NamedArg* arg = "path" in func.arguments.namedArgs) {
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

EvalResult evalVideo(FuncCall func) {
    EvalResult result;
    // TODO: these functions need error reporting
    Video video;
    if (func.arguments.positionalArgs.length == 1) {
        LocatedVal!DslType val = func.arguments.positionalArgs[0];
        EvalResult res = evalValue(val);
        result.absorb(res);
        if (res.ok && res.value.has!string) {
            video.path = res.value.get!string;
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(val, "video");
        }
        result.ok = true;
        result.value = SlidexType(video);
    }
    else if (NamedArg* arg = "path" in func.arguments.namedArgs) {
        EvalResult res = evalValue(arg.value);
        result.absorb(res);
        if (res.ok && res.value.has!string) {
            video.path = res.value.get!string;
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(arg.value, "video");
        }
        result.ok = true;
        result.value = SlidexType(video);
    }
    return result;
}
