module parser;

import std.algorithm.searching;
import std.algorithm.iteration;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.format;
import std.random;
import std.range;
import std.stdio;
import std.sumtype;
import std.uni : asCapitalized;

import pegged.grammar;

import ast;
import resolver;
import common;

mixin(grammar(import("grammar.peg")));

alias LocatedResult(T) = Result!(LocatedVal!T);

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
    }
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

        Result!Deck result = Result!Deck(ok : true);
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
        VoidResult result = VoidResult(ok : true);
        foreach (child; root.children) {
            if (child.name == "SlidexDoc.DeckContent") {
                VoidResult res = parseDeckContent(child, deck);
                result.absorb(res);
            }
        }
        return result;
    }

    VoidResult parseDeckContent(ParseTree root, Deck deck) {
        VoidResult result = VoidResult(ok : true);
        foreach (child; root.children) {
            if (child.name == "SlidexDoc.ValueAssignment") {
                LocatedVal!string ident = getQualifiedIdentifier(child[0]);
                switch (ident.value) {
                    // TODO: use static foreach to generate field assignment
                    // TODO: replace with ExtractValue
                case "author":
                    auto res = extractString(getValue(getAssignmentValueNode(child)));
                    // auto res = extractValue!string(deck.author, "author", value);
                    result.absorb(res).ifSome((s) { deck.author = s; });
                    break;
                case "date":
                    auto res = extractDate(getValue(getAssignmentValueNode(child)));
                    result.absorb(res).ifSome((d) { deck.date = d; });
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

        Result!Master result = Result!Master(ok : true, value:
            master);

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

        Result!Item result = Result!Item(ok : true);

        // TODO: check if this symbol is already defined in the master and refuse if so

        if (pd.ident.value is null)
            pd.ident.value = iota(26).randomSample(8).map!(x => to!char(x + 'a')).array.idup;

        if (pd.value.value.has!FuncCall) {
            FuncCall call = pd.value.value.get!FuncCall();
            switch (call.name) {
            case "rect":
                // factor out
                Rect rect;
                foreach (k, v; call.namedArgs) {
                    switch (k) {
                    case "fill":
                        // TODO: parse colour or func.
                        LocatedResult!RgbColour res = extractColour(v.value);
                        result.absorb(res).ifSome((c) { rect.fill = c; });
                        break;
                    default:
                        result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, v.name.loc, "Unknown argument name `" ~ v
                                .name ~ "`");
                        result.ok = false;
                        break;
                    }
                }
                if (result.ok) {
                    Item item = new Item(pd.ident.value);
                    item.loc = pd.value.loc;
                    item.layoutLocation = pd.layoutLocation;
                    item.shape = rect;
                    result.value = item;
                }
                break;
            case "text":
                // Deal with errors
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
                // TODO: Factor out
                Image image;
                if (call.positionalArgs.length > 0 && call.positionalArgs[0].has!string) {
                    image.path = call.positionalArgs[0].get!string;
                }
                else if (auto val = "path" in call.namedArgs) {
                    if (val.value.has!string) {
                        image.path = val.value.get!string;
                    }
                    else {
                        result.ok = false;
                        result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, val.value.loc, "Invalid type. Expected string but got `" ~ val
                                .value.typeName ~ "` .");
                    }
                }
                Item item = new Item(pd.ident.value);
                item.loc = pd.value.loc;
                item.layoutLocation = pd.layoutLocation;
                item.shape = image;
                result.value = item;
                break;
            default:
                result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownElement, Severity.Error, call.name.loc, "Unknown element `" ~ call
                        .name ~ "`.");
                result.ok = false;
                break;
            }
        }
        else {
            result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, pd.value.loc, "Property elements must be presentation elements such as Text, Text, Image, ...");
            result.ok = false;

        }
        return result;
    }

    VoidResult parseMasterContent(ParseTree root, Master master) {

        VoidResult handleValueAssignment(ValueAssignment va) {
            // assign properties
            VoidResult r1 = VoidResult(ok : true);
            // writeln("handleValueAssignment(): ", va.ident);
            switch (va.ident) {
                // TODO: invent better way to avoid code duplication
            case "columns":
                auto res = extractNumber(va.value);
                r1.absorb(res).ifSome((n) { master.columns = n; });
                break;
            case "rows":
                auto res = extractNumber(va.value);
                r1.absorb(res).ifSome((n) { master.rows = n; });
                break;
            case "showgrid":
                auto res = extractBool(va.value);
                r1.absorb(res).ifSome((b) { master.showgrid = b; });
                break;
            case "background":
                // assert(false, "Rgb Parsing not implemented");
                LocatedResult!RgbColour res = extractColour(va.value);
                r1.absorb(res).ifSome((c) { master.background = c.value; });
                if (!res.ok) {
                    if (va.value.has!FuncCall && va.value.get!FuncCall().name == "image") {
                        // TODO: use central function to create Image
                        master.background = Image(va.value.get!FuncCall()
                                .namedArgs["path"].value.value.get!string);
                        r1.ok = true;
                    }
                    else {
                        r1.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, va.value.loc, "Invalid type `" ~
                                va.value.typeName ~ "`. Expected colour or image but found `" ~ va.value.get!FuncCall()
                                .name ~ "`");
                    }
                }
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
            // writeln("handlePropertyDeclaration(): ", pd);
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
        VoidResult result = VoidResult(ok : true);

        foreach (child; root.children) {

            // master slides currently only contain statements.
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

        Result!Slide result = Result!Slide(ok : true);
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
            // LATER: currently here are no fields

            // if not, then keep it for later when the master is resolved.
            slide.assignments ~= va;
            return VoidResult(ok : true);
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

        VoidResult result = VoidResult(ok : true);

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

        Result!Statement result;

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.PropertyDeclaration":
                // writeln("->Property Declaration");
                Result!PropertyDeclaration res = parsePropertyDeclaration(child);
                result.absorb(res);
                if (res.ok) {
                    result.value = res.value;
                    result.ok = true;
                }
                break;
            case "SlidexDoc.ValueAssignment":
                // writeln("-> Value Assignment");
                ValueAssignment assignment;
                assignment.ident = getQualifiedIdentifier(child[0]);
                assignment.value = getValue(getAssignmentValueNode(child));
                result.value = Statement(assignment);
                result.ok = true;
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
        Result!PropertyDeclaration result = Result!PropertyDeclaration(ok : true);

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
  for root pass in a "SlidexDoc.[String,Number,Colour,Text,Date,FuncCall]"
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
        case "SlidexDoc.Text":
            return locatedDslType(root.matches[0], loc);
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

    // TODO: move helper
    private Diagnostic createInvalidTypeDiag(LocatedVal!DslType val, string expectedType) {
        return Diagnostic(DiagnosticKind.InvalidType,
            Severity.Error, val.loc, "Invalid value `" ~ val.value.toVariant.toString() ~ "`. Expected a " ~ expectedType ~ " but got " ~ val
                .value.typeName() ~ ".");
    }

    /**
        returns the DSL friendly name for the type of this value
        */
    // TODO: move helper
    // private string getTypename(ParseTree valueNode) {
    //     writeln("********: ", valueNode);
    //     switch (valueNode.name) {
    //     case "SlidexDoc.Number":
    //         return "number";
    //     case "SlidexDoc.Quantity":
    //         assert(false, "implement name for quantity");
    //     case "SlidexDoc.NamedColour":
    //         return "colour";
    //     case "SlidexDoc.Boolean":
    //         return "boolean";
    //     case "SlidexDoc.Text":
    //         return "text";
    //     case "SlidexDoc.Date":
    //         return "date";
    //     case "SlidexDoc.FuncCall":
    //         return "function";
    //     case "SlidexDoc.QualifiedIdentifier":
    //         return "identifier";
    //     default:
    //         // writeln(root);
    //         assert(false, "Type name for value `" ~ valueNode.name ~ "` not implemented yet");
    //     }
    // }

    /** returns a string from a Value
     * valueNode is a ParseTree node to the value
     */
    LocatedResult!string extractString(LocatedVal!DslType val) {
        LocatedResult!string result;
        if (val.value.has!string) {
            result.ok = true;
            result.value = LocatedVal!string(val.value.get!string, val.loc);
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(val, "string");
        }
        return result;
    }

    LocatedResult!int extractNumber(LocatedVal!DslType val) {
        LocatedResult!int result;
        if (val.value.has!int) {
            result.ok = true;
            result.value = LocatedVal!int(val.value.get!int, val.loc);
        }
        else if (val.value.has!Quantity) {
            Quantity qty = val.value.get!Quantity;
            if (qty.unit.value == null) {
                result.ok = true;
                result.value = LocatedVal!int(cast(int) qty.value.value, qty.value.loc);
            }
        }
        if (!result.ok)
            result.diagnostics ~= createInvalidTypeDiag(val, "number");

        return result;
    }

    LocatedResult!float extractFloat(LocatedVal!DslType val) {
        LocatedResult!float result;
        if (val.value.has!float) {
            result.ok = true;
            result.value = LocatedVal!float(val.value.get!float, val.loc);
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(val, "float");
        }
        return result;
    }

    LocatedResult!bool extractBool(LocatedVal!DslType val) {
        LocatedResult!bool result;
        if (val.value.has!bool) {
            result.ok = true;
            result.value = LocatedVal!bool(val.value.get!bool, val.loc);
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(val, "boolean");
        }
        return result;
    }

    LocatedResult!RgbColour extractColour(LocatedVal!DslType val) {
        LocatedResult!RgbColour result;
        if (val.value.has!NamedColour) {
            result.ok = true;
            result.value = LocatedVal!RgbColour(namedColourToRgb(val.value.get!NamedColour), val
                    .loc);
        }
        else if (val.value.has!FuncCall) {
            // TODO: refactor this monster.
            FuncCall rgb = val.value.get!FuncCall;
            if (rgb.name.value == "rgb") {
                // TODO: factor out evaluating RGB
                if (rgb.namedArgs.length > 0) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, rgb.name.loc, "rgb() colours do not accept named arugments. Expected rgb(r,g,b) or rgb(\"#12ab7f\")");
                    result.ok = false;
                }
                else if (rgb.positionalArgs.length == 3) {
                    // parse components
                    bool success = true;
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
                            result.value[i] = cast(ubyte) rgb.positionalArgs[i].value.get!Quantity.value.value;
                        }
                    }
                    if (success)
                        result.ok = true;
                }
                else if (rgb.positionalArgs.length == 1 && rgb.positionalArgs[0].value.has!string) {
                    // parse string

                    string hexval = rgb.positionalArgs[0].value.get!string;
                    bool success = false;
                    if (hexval[0] == '#') {
                        try {
                            ubyte[] triplet = hexval[1 .. $].fromHex;
                            if (triplet.length == 3) {
                                for (size_t i = 0; i < 3; i++) {
                                    result.value[i] = triplet[i];
                                }
                                success = true;
                            }
                        }
                        catch (Exception e) {
                            writeln("failed: ", e);
                            success = false;
                        }
                    }
                    if (success)
                        result.ok = true;
                    else
                        result.diagnostics ~= Diagnostic(DiagnosticKind.ParseError, Severity.Error, rgb.positionalArgs[0].loc, "Invalid hex colour value: Expected \"#rrggbb\" but got `" ~ hexval ~ "`.");
                }
                else {
                    writeln("VAL: " ,rgb.positionalArgs);
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownArgument, Severity.Error, rgb.name.loc, "Invalid number of arguments `" ~ rgb
                            .positionalArgs.length.to!string ~ "` Expected rgb(r,g,b) or rgb(\"0x12ab7f\")");
                }
            }
            else {
                result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, val.loc, "Invalid value `" ~ val
                        .value.toVariant().toString() ~ "` Expected a colour but got function call");
            }
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(val, "colour");
        }
        return result;
    }

    /** extracts a date type from a parse tree
      * value node that is the date
      */
    LocatedResult!Date extractDate(LocatedVal!DslType val) {
        LocatedResult!Date result;
        if (val.value.has!Date) {
            result.ok = true;
            result.value = LocatedVal!Date(val.value.get!Date, val.loc);
        }
        else {
            result.diagnostics ~= createInvalidTypeDiag(val, "date");
        }
        return result;
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
                break;
            case "SlidexDoc.ArgList":
                args = getNamedArguments(child);
                break;
            default:
                break;
            }
        }

        Result!LayoutLocation result = Result!LayoutLocation(ok : true);
        if (locKind == LocationKind.Cell) {
            CellLocation cell;
            foreach (argname; args.keys) {
                switch (argname) {
                case "col":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { cell.col = n - 1; });
                    break;
                case "row":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { cell.row = n - 1; });
                    break;
                case "colspan":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { cell.colspan = n; });
                    break;
                case "rowspan":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { cell.rowspan = n; });
                    break;
                case "dx":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { cell.dx = n; });
                    break;
                case "dy":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { cell.dy = n; });
                    break;
                case "angle":
                    auto res = extractFloat(args[argname].value);
                    result.absorb(res).ifSome((f) { cell.angle = f; });
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
            foreach (argname; args.keys) {
                switch (argname) {
                case "x":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { bounds.x = n; });
                    break;
                case "y":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { bounds.y = n; });
                    break;
                case "width":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { bounds.width = n; });
                    break;
                case "height":
                    auto res = extractNumber(args[argname].value);
                    result.absorb(res).ifSome((n) { bounds.height = n; });
                    break;
                case "angle":
                    auto res = extractFloat(args[argname].value);
                    result.absorb(res).ifSome((f) { bounds.angle = f; });
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
