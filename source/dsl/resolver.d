module resolver;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
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

Result!(types.TextAlignment) alignmentToTextAlignment(dsl.ast.Alignment alignment) {
    Result!(types.TextAlignment) result = Result!(types.TextAlignment)(ok: true);
    switch (alignment) {
    case dsl.ast.Alignment.Left:
        result.value = types.TextAlignment.Left;
        break;
    case dsl.ast.Alignment.Right:
        result.value = types.TextAlignment.Right;
        break;
    case dsl.ast.Alignment.Centre:
        result.value = types.TextAlignment.Centre;
        break;
    default:
        // TODO: add source location
        result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidValue, Severity.Error, SourceLocation(), "Invalid text alignment value `" ~ alignment
                .to!string ~ "`. Expected: left, right, centre");
        result.ok = false;
    }
    return result;
}

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
        slides.Slide toSlide = new slides.Slide(fromSlide.name.value);

        // build master
        if (auto fromMaster = fromSlide.masterName.value in root.masterMap) {
            Result!(slides.Master) res = buildMaster(*fromMaster);
            result.absorb(res);
            if (res.ok) {
                toSlide.master = res.value;
            }
        }
        else if (fromSlide.masterName is null || root.masterMap.length == 0) {
            result.diagnostics ~= Diagnostic(DiagnosticKind.UnresolvedMaster, Severity.Warning, fromSlide.name.loc, "Slide " ~ fromSlide
                    .name ~ " has no master assigned.");
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
            writeln("Assignment: ", assignment);

            // TODO: test whether there are no duplicate property identifiers between master and slides
            // search items in master
            // Not only search for duped items, also search for property - item name clashes
            string ident = (cast(string) assignment.ident.value[0]);
            EvalResult evaluatedResult = evalValue(assignment.value);
            if (!evaluatedResult.ok) {
                result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidValue, Severity.Error, assignment.value.loc, "Can't evaluate value `" ~ assignment
                        .value.value.to!string ~ "`");
                result.ok = false;
                continue;
            }

            Result!PropertyType r1 = slidexValueToPropertyValue(evaluatedResult.value);
            result.absorb(r1);
            if (!r1.ok)
                continue;
            PropertyType propval = r1.value;

            // Variant var = evaluatedResult.value.toVariant;

            // if (var.convertsTo!Quantity) {
            //     EvalResult res = evalQuantity(var.get!Quantity);
            //     result.absorb(res);
            //     if (res.ok) {
            //         // Convert Typedef wrappers here.
            //         if (res.value.has!Seconds)
            //             var = cast(int) res.value.get!Seconds;
            //         if (res.value.has!(Percent))
            //             var = cast(int) res.value.get!Percent;
            //         if (res.value.has!(Centimeter))
            //             var = cast(int) res.value.get!Centimeter;
            //         if (res.value.has!int) {
            //             var = res.value.get!int;
            //         }
            //     }
            //     else {
            //         assert(false, "Failed quantity conversion");
            //     }
            // }
            // else if (var.convertsTo!RichText) {
            //     // RichText nodes are processed first
            //     RichText rt = var.get!RichText;
            //     Result!RichText res = resolveRichText(rt);
            //     if (res.ok) {
            //         var = res.value;
            //     }
            //     else {
            //         assert(false, "Error processing richtext assignment");
            //     }
            // }
            // else if (var.convertsTo!NamedColour) {
            //     var = Variant(namedColourToRgb(var.get!NamedColour));
            // }

            slides.Item* item;
            if (toSlide.master !is null)
                item = ident in toSlide.master.itemsMap;
            if (item is null)
                item = ident in toSlide.itemsMap;

            if (item !is null) {

                // TODO: get rid of the variant.

                string propName = cast(string) assignment.ident.value[1];
                if (!item.hasProperty(propName)) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, assignment.value.loc, "No such property `" ~
                            propName ~ "` on element `" ~
                            cast(string) assignment.ident.value[0] ~ "`");
                    result.ok = false;
                }
                else if (!item.setProperty(propName, propval)) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, assignment.value.loc, "Unable to set value: `" ~
                            propval.typeName() ~ "` for item field `" ~ ident ~ "`");
                    result.ok = false;
                }
            }
            else if (toSlide.hasProperty(ident)) {
                // The item is a fixed property field of the slide.
                // TODO: evaluate type to slides type
                toSlide.setProperty(ident, propval);
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

    Result!(slides.Rect) buildRect(string name, dsl.ast.Rect r) {
        return Result!(slides.Rect)(ok: true, value: new slides.Rect(name, r.fill));
    }

    Result!(slides.Text) buildText(string name, dsl.ast.Text t) {
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
        // TODO: keep symbol table??
        symboltable[name] = SlidexTypeKind.Text;
        slides.Text text = new slides.Text(name, rt, t.colour, t.size);
        Result!TextAlignment res = alignmentToTextAlignment(t.alignment);
        if (res.ok) {
            text.alignment = res.value;
        }
        else {
            assert(false, "Conversion of text alignment failed");
        }

        // return result errors in this function
        return Result!(slides.Text)(ok: true, value: text);
    }

    Result!(slides.Image) buildImage(string name, dsl.ast.Image i) {
        symboltable[name] = SlidexTypeKind.Image;
        return Result!(slides.Image)(ok: true, value: new slides.Image(name, i.path));
    }

    Result!(slides.Video) buildVideo(string name, dsl.ast.Video m) {
        symboltable[name] = SlidexTypeKind.Video;
        return Result!(slides.Video)(ok: true, value: new slides.Video(name, m.path));
    }

    Result!(slides.Item) buildItem(dsl.ast.Item fromItem) {

        Result!(slides.Item) toItem = fromItem.shape.match!(
            // TODO: return errors
                (dsl.ast.Rect r) => cast(Result!(slides.Item)) buildRect(fromItem.name, r),
                (dsl.ast.Text t) => cast(Result!(slides.Item)) buildText(fromItem.name, t),
                (dsl.ast.Image i) => cast(Result!(slides.Item)) buildImage(fromItem.name, i),
                (dsl.ast.Video v) => cast(Result!(slides.Item)) buildVideo(fromItem.name, v),
        );

        if (!toItem.ok)
            return Result!(slides.Item)(ok: false);

        toItem.value.layoutLocation = fromItem.layoutLocation;
        return toItem;
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

    Result!PropertyType slidexValueToPropertyValue(SlidexType value) {
        // SlidexTypes = AliasSeq!(int, float, bool, string, Date, RgbColour, RichText,
        //  Image, Rect, Text, Video, Seconds, Percent, Centimeter, Fraction, Pixel,
        //  TAlignment, TCellAlignment, SlidexArray);
        // TODO: can I improve this monstrosity?
        return value.match!(
            // if (value.has!int())
                //     return Result!PropertyType(ok: true, value: PropertyType(value.get!int));
                // else if (value.has!float)
                //   return Result!PropertyType(ok: true, value: PropertyType(value.get!float));
                // else if (value.has!bool)
                //     return Result!PropertyType(ok: true, value: PropertyType(value.get!bool));
                // else if (value.has!string)
                (bool b) => Result!PropertyType(ok: true, value: PropertyType(Bool(b))),
                (int i) => Result!PropertyType(ok: true, value: PropertyType(Int(i))),
                (float f) => Result!PropertyType(ok: true, value: PropertyType(Float(f))),
                (string s) => Result!PropertyType(ok: true, value: PropertyType(s)),
                (Date d) => Result!PropertyType(ok: true, value: PropertyType(d)),
                (RgbColour rgb) => Result!PropertyType(ok: true, value: PropertyType(rgb)),
                (RichText rt) => Result!PropertyType(ok: true, value: PropertyType(rt)),
                (dsl.ast.Rect r) {
                Result!(slides.Rect) res = buildRect("anonymous", r);
                if (!res.ok)
                    return Result!PropertyType(ok: false);
                return Result!PropertyType(ok: true, value: PropertyType(res.value));
            },
                (dsl.ast.Text t) {
                Result!(slides.Text) res = buildText("anonymous", t);
                if (!res.ok)
                    return Result!PropertyType(ok: false);
                return Result!PropertyType(ok: true, value: PropertyType(res.value));
            },
                (dsl.ast.Image i) {
                Result!(slides.Image) res = buildImage("anonymous", i);
                if (!res.ok)
                    return Result!PropertyType(ok: false);
                return Result!PropertyType(ok: true, value: PropertyType(res.value));
            },
                (dsl.ast.Video v) {
                Result!(slides.Video) res = buildVideo("anonymous", v);
                if (!res.ok)
                    return Result!PropertyType(ok: false);
                return Result!PropertyType(ok: true, value: PropertyType(res.value));
            },

                (Seconds s) => Result!PropertyType(ok: true, value: PropertyType(cast(Int) s)),
                (Percent p) => Result!PropertyType(ok: true, value: PropertyType(cast(Int) p)),
                (Centimeter c) => Result!PropertyType(ok: true, value: PropertyType(cast(Int) c)),
                (Fraction f) => Result!PropertyType(ok: true, value: PropertyType(cast(Float) f)),
                (Pixel p) => Result!PropertyType(ok: true, value: PropertyType(cast(Int) p)),
                // TODO: fix next two conversions
                (TAlignment a) => Result!PropertyType(ok: true),
                (TCellAlignment ca) => Result!PropertyType(ok: true),
                // END
                (SlidexArray sa) => Result!PropertyType(ok: false),
        );
    }

}
