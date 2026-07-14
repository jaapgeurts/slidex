module resolver;

import std.algorithm;
import std.array;
import std.stdio;
import std.sumtype;
import std.variant;

import common;
import dsl.ast;
import dsl.parser;
import slides;
import types;

// Result!Unit stringToUnit(string str, SourceLocation loc) {
//     final switch (str) {
//     case "s":
//         return Result!Unit(ok: true, value: Unit.Seconds);
//     case "fr":
//         return Result!Unit(ok: true, value: Unit.Fraction);
//     case "cm":
//         return Result!Unit(ok: true, value: Unit.Centimeter);
//     case "%":
//         return Result!Unit(ok: true, value: Unit.Percent);
//     case "px":
//         return Result!Unit(ok: true, value: Unit.Pixel);
//     }
//     return Result!Unit(ok: false, diagnostics: [
//         Diagnostic(DiagnosticKind.InvalidUnit, Severity.Error, loc, "Invalid unit name `" ~ str ~ "` conversion not implemented.")
//     ]);
// }

struct AbstractTree {
    dsl.parser.Deck root;
    string sourceFilePath;

    Result!(slides.Deck) resolveAst() {
        // assert(false,__FUNCTION__ ~ "() not yet implemented.");
        Result!(slides.Deck) result;
        result.ok = true;

        slides.Deck toDeck = new slides.Deck();

        // build slides
        foreach (fromSlide; root.slides) {
            Result!(slides.Slide) res = buildSlide(fromSlide);
            result.absorb(res);
            // add the slide to the deck.
            toDeck.slides ~= res.value;
        }

        result.value = toDeck;
        return result;
    }

private:

    enum SlidexTypeKind {
        Text,
        Image,
        Video,
    }

    SlidexTypeKind[string] symboltable;

    Result!(slides.Slide) buildSlide(dsl.ast.Slide fromSlide) {

        Result!(slides.Slide) result = Result!(slides.Slide)(ok: true);
        slides.Slide toSlide = new slides.Slide(fromSlide.name);

        // build master
        if (auto fromMaster = fromSlide.masterName.value in root.masterMap) {
            Result!(slides.Master) res = buildMaster(*fromMaster);
            result.absorb(res);
            if (res.ok) {
                toSlide.master = res.value;
            }
        }
        else {
            result.ok = false;
            result.diagnostics ~= Diagnostic(DiagnosticKind.UnresolvedMaster, Severity.Error, fromSlide.masterName.loc, "Unknown master reference: " ~
                    fromSlide.masterName.value);
        }

        // build slide items
        foreach (fromItem; fromSlide.items) {

            Result!(slides.Item) res = buildItem(fromItem);
            result.absorb(res).ifSome((i) {
                toSlide.items ~= res.value;
                toSlide.itemsMap[res.value.name] = res.value;
            });
        }

        // build slide sequences if any.
        foreach (fromEvent; fromSlide.sequencelist.events) {
            Result!(slides.Event) res = buildEvent(fromEvent);
            result.absorb(res).ifSome((e) { toSlide.events ~= e; });
        }

        // TODO: check if symbols are duplicated between master and slide
        // apply deferred assignments
        foreach (assignment; fromSlide.assignments) {
            // writeln("Assignment: " , assignment);

            // TODO: support slide assignments (currently only assignments to master items are supported).
            if (toSlide.master is null) {
                result.diagnostics ~= Diagnostic(DiagnosticKind.GeneralError, Severity.Warning, SourceLocation("", 0), "Slide `" ~ fromSlide.name ~ "` has no master attached. Slides without a master are currently unsupported.");
                continue;
            }

            // TODO: test whether there are no duplicate property identifiers between master and slides
            // search items in master
            string ident = (cast(string) assignment.ident.value[0]);
            Variant var = assignment.value.value.toVariant;
            slides.Item* item = ident in toSlide.master.itemsMap;
            // no item with that name in the master, then check the slide
            if (item is null) {
                item = ident in toSlide.itemsMap;
            }
            if (item !is null) {

                // TODO: get rid of the variant.

                if (var.convertsTo!(Quantity)) {
                    EvalResult res = evalQuantity(var.get!Quantity);
                    result.absorb(res);
                    if (res.ok) {
                        // Convert Typedef wrappers here.
                        if (res.value.has!Seconds)
                            var = cast(int) res.value.get!Seconds;
                        if (res.value.has!(Percent))
                            var = cast(int) res.value.get!Percent;
                        if (res.value.has!(Centimeter))
                            var = cast(int) res.value.get!Centimeter;
                        if (res.value.has!int) {
                            var = res.value.get!int;
                        }
                    }
                    else {
                        assert(false, "Failed quantity conversion");
                    }
                }
                else if (var.convertsTo!(RichText)) {
                    // RichText nodes are processed first
                    RichText rt = var.get!RichText;
                    Result!RichText res = resolveRichText(rt);
                    if (res.ok) {
                        var = res.value;
                    }
                    else {
                        assert(false, "Error processing richtext assignment");
                    }
                }
                string propName = cast(string) assignment.ident.value[1];
                if (!item.hasProperty(propName)) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, assignment.value.loc, "No such property `" ~
                            propName ~ "` on element `" ~
                            cast(
                                string) assignment.ident.value[0] ~ "`");
                    result.ok = false;
                }
                else if (!item.isPropertyType(propName, var)) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, assignment.value.loc, "Invalid type: `" ~
                            assignment.value.value.typeName ~ "` for field `" ~ assignment.ident.value.toString ~ "`");
                    result.ok = false;
                }
                else if (!item.setProperty(propName, var)) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, assignment.value.loc, "Unable to set value: `" ~
                            assignment.value.value.typeName ~ "` for field `" ~ assignment.ident.value.toString ~ "`");
                    result.ok = false;
                }
            }
            else if (toSlide.hasProperty(ident)) {
                // The item is a property field of the slide.
                if (toSlide.isPropertyType(ident, var)) {
                    toSlide.setProperty(ident, var);
                }
                else {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, assignment.value.loc, "Invalid type: `" ~
                            assignment.value.value.typeName ~ "` for field `" ~ assignment.ident.value.toString ~ "`");
                    result.ok = false;
                }

            }
            else {
                result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownElement, Severity.Error, assignment.ident.loc, "Undefined element `" ~
                        cast(string) assignment.ident.value[0] ~ "`");
                result.ok = false;
            }
            // writeln("Assignment succeeded: ", assignment);

        }

        // TODO: cross check all symbol references. (2-pass)

        result.value = toSlide;

        return result;
    }

    Result!(slides.Master) buildMaster(dsl.ast.Master fromMaster) {
        Result!(slides.Master) result = Result!(slides.Master)(ok: true);

        // TODO: verify if columns counts and span match
        // TODO: test for illegal combinations for columns/rows
        // and positioning
        IntOrLength cols = fromMaster.columns.match!(
            (int i) { return IntOrLength(i); },
            (SlidexArray arr) {
            Length[] lengths;
            foreach (arg; arr.items) {
                if (arg.value.has!Pixel)
                    lengths ~= Length(cast(float) arg.value.get!Pixel, DimensionUnit.Pixel);
                else if (arg.value.has!Fraction)
                    lengths ~= Length(cast(float) arg.value.get!Fraction, DimensionUnit.Fraction);
                else {
                    result.ok = false;
                    result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidUnit, Severity.Error, arg.loc, "columns values must specify a unit, or unit not implemented yet");
                }
            }
            return IntOrLength(lengths);
        });

        IntOrLength rows = fromMaster.rows.match!(
            (int i) { return IntOrLength(i); },
            (SlidexArray arr) {
            Length[] lengths;
            foreach (arg; arr.items) {
                if (arg.value.has!Pixel)
                    lengths ~= Length(cast(float) arg.value.get!Pixel, DimensionUnit.Pixel);
                else if (arg.value.has!Fraction)
                    lengths ~= Length(cast(float) arg.value.get!Fraction, DimensionUnit.Fraction);
                else {
                    result.ok = false;
                    result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidUnit, Severity.Error, arg.loc, "columns values must specify a unit, or unit not implemented yet");
                }
            }
            return IntOrLength(lengths);
        });

        // writeln("COLS: ", cols);
        // writeln("ROWS: ", rows);

        slides.Master toMaster = new slides.Master(fromMaster.name, cols, rows);
        // build master items
        foreach (fromItem; fromMaster.items) {
            Result!(slides.Item) res = buildItem(fromItem);
            result.absorb(res);
            if (res.ok) {
                toMaster.items ~= res.value;
                toMaster.itemsMap[res.value.name] = res.value;
            }
        }

        fromMaster.background.match!(
            (RgbColour c) { toMaster.background = c; },
            (dsl.ast.Image i) {
            toMaster.background = new slides.Image("backgroundimage", i.path);
        }
        );

        result.value = toMaster;
        return result;
    }

    Result!(slides.Item) buildItem(dsl.ast.Item fromItem) {
        slides.Item toItem = fromItem.shape.match!(
            (dsl.ast.Rect r) => cast(slides.Item) new slides.Rect(fromItem.name, r.fill),
            (dsl.ast.Text t) {
            RichText rt;
            if (t.content !is null) {
                Result!RichText res = resolveRichText(t.content);
                if (res.ok) {
                    rt = res.value;
                }
                else {
                    assert(false, "handling error during rich tech resolve not implemented");
                }
            }
            symboltable[fromItem.name] = SlidexTypeKind.Text;
            return new slides.Text(fromItem.name, rt, t.colour, t.size);
        },
            (dsl.ast.Image i) {
            symboltable[fromItem.name] = SlidexTypeKind.Image;
            return new slides.Image(fromItem.name, i.path);
        },
            (dsl.ast.Video m) {
            symboltable[fromItem.name] = SlidexTypeKind.Video;
            return new slides.Video(fromItem.name, m.path);
        },
        );

        toItem.layoutLocation = fromItem.layoutLocation;

        return Result!(slides.Item)(ok: true, value: toItem);
    }

    Result!RichText resolveRichText(RichText rt) {
        Result!RichText result = Result!RichText(ok: true);
        assert(rt !is null, "Error: argument RichText is null");

        // evaluate

        result.value = new RichText(resolveItems(rt.items));
        return result;
    }

    TextItem[] resolveItems(ref TextItem[] srcItems) {
        // TODO: change to appender. It refuses the type Appender!TextItem
        TextItem[] items;

        for (size_t i; i < srcItems.length; ++i) {
            srcItems[i].match!(
                (Word w) { items ~= TextItem(w); },
                (LineBreak lb) { items ~= TextItem(lb); },
                (EscapedChar ec) { items ~= TextItem(ec); },
                (Bold b) { items ~= TextItem(b); },
                (Italic i) { items ~= TextItem(i); },
                (Underline u) { items ~= TextItem(u); },
                (Variable v) {
                stderr.writeln("TODO: variable resolution not implemented.");
                items ~= TextItem(v);
            },
                (InlineFunc f) {
                writeln("resolving function");
                Result!TextItem res = evalInlineFunction(f);
                if (res.ok) {
                    items ~= res.value;
                }
                else {
                    assert(false, "eval function failed");
                }
            },
                (ListBlock lb) {
                foreach (ref li; lb.items) {
                    li.content = resolveItems(li.content);
                }
                items ~= TextItem(lb);
            },
                (Code c) { items ~= TextItem(c); },
            );
        }
        return items;
    }

    // TODO: rewrite this to general function evaluation
    Result!TextItem evalInlineFunction(InlineFunc fi) {

        switch (fi.name) {
        case "bold":
            writeln("resolving bold");
            TextItem ti = Bold(fi.items);
            return Result!TextItem(ok: true, value: ti);
        case "italic":
            writeln("resolving italic");
            TextItem ti = Italic(fi.items);
            return Result!TextItem(ok: true, value: ti);
        case "underline":
            TextItem ti = Underline(fi.items);
            return Result!TextItem(ok: true, value: ti);
        default:
            assert(false, "Unknown function handling not implemented. Function name: " ~ fi.name);
        }
        assert(false, "Unreachable");
    }

    Result!(slides.Event) buildEvent(dsl.ast.Event fromEvent) {
        Result!(slides.Event) result;
        fromEvent.match!(
            (dsl.ast.TimerEvent te) {
            EvalResult res = evalQuantity(te.quantity);
            if (res.ok) {
                if (res.value.has!Seconds) {
                    int secs = cast(int) res.value.get!Seconds;
                    if (secs >= 0) {
                        result.value = new slides.TimerEvent(secs);
                        Result!Function r1 = buildFunction(te.func);
                        if (r1.ok) {
                            result.value.func = r1.value;
                            result.ok = true;
                        }
                    }
                    else {
                        result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidValue, Severity.Error, te
                            .quantity.value.loc, "Negative values are not allowed.");
                    }
                }
                else {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidUnit, Severity.Error, te.quantity.value.loc, "Timer values only accept second values.");
                }
            }
        },
            (dsl.ast.OnClickEvent ce) {
            result.value = new slides.OnClickEvent();
            result.ok = true;
            Result!Function res = buildFunction(ce.func);
            result.absorb(res).ifSome((f) { result.value.func = f; });
        }
        );
        return result;
    }

    Result!Function buildFunction(FuncCall fromFunc) {
        Function toFunc = new Function();
        toFunc.name = cast(string) fromFunc.name.value;
        if (fromFunc.arguments.namedArgs.length > 0)
            assert(false, "Named arguments are currently not supported for event function calls");
        foreach (fromVal; fromFunc.arguments.positionalArgs) {
            if (fromVal.value.has!QualifiedIdentifier) {

                string ident = cast(string) fromVal.value.get!QualifiedIdentifier.identifiers[0];
                if (ident !in symboltable) {
                    assert(false, "Undefined identifier `" ~ ident ~ "`");
                }
                else {
                    // perhaps the identifier is in the table, but it's the wrong type
                }
                // TODO: this implementation is wonky.
                import std.conv;

                toFunc.positionalargs ~= Variant(fromVal.value
                        .get!QualifiedIdentifier
                        .identifiers
                        .map!(to!string)
                        .join('.'));
            }
            else {
                assert(false, "Values other than QualifiedIdentifiers are currently not supported");
            }
        }
        return Result!Function(ok: true, toFunc);

    }

}
