module resolver;

import std.array;
import std.stdio;
import std.sumtype;
import std.variant;

import ast;
import parser;
import slides;
import common;

struct AbstractTree {
    parser.Deck root;
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

    Result!(slides.Slide) buildSlide(ast.Slide fromSlide) {

        Result!(slides.Slide) result = Result!(slides.Slide)(ok: true);
        slides.Slide toSlide = new slides.Slide(fromSlide.name);

        // build master
        if (auto fromMaster = fromSlide.masterName.value in root.masterMap) {
            Result!(slides.Master) res = buildMaster(*fromMaster);
            result.absorb(res);
            if (res.ok)
                toSlide.master = res.value;
        }
        else {
            result.ok = false;
            result.diagnostics ~= Diagnostic(DiagnosticKind.UnresolvedMaster, Severity.Error, fromSlide.masterName.loc, "Unknown master reference: " ~
                    fromSlide.masterName.value);
        }

        // build slide items
        foreach (fromItem; fromSlide.items) {

            Result!(slides.Item) res = buildItem(fromItem);
            result.absorb(res);
            toSlide.items ~= res.value;
            toSlide.itemsMap[res.value.name] = res.value;
        }

        // TODO: check if symbols are duplicated between master and slide
        // apply deferred assignments
        foreach (assignment; fromSlide.assignments) {
            // writeln("Assignment: " , assignment);
            string[] parts = assignment.ident.value.split('.');

            // TODO: support slide assignments (currently only assignments to master items are supported).
            if (toSlide.master is null)
                continue;

            // search items in master
            if (auto item = parts[0] in toSlide.master.itemsMap) {

                Variant var = assignment.value.value.toVariant;

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
                    var = cast(string) var.get!RichText;
                }

                if (!item.hasProperty(parts[1])) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, assignment.value.loc, "No such property `" ~ parts[1] ~ "` on element `" ~ parts[0] ~ "`");
                    // TODO: for correct location reporting increase the col location here with the length of the parts[1] 
                    result.ok = false;
                }
                else if (!item.isPropertyType(parts[1], var)) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.InvalidType, Severity.Error, assignment.value.loc, "Invalid type: `" ~
                            assignment.value.value.typeName ~ "` for field `" ~ assignment.ident.value ~ "`");
                    result.ok = false;
                }
                else if (!item.setProperty(parts[1], var)) {
                    result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownProperty, Severity.Error, assignment.value.loc, "Unable to set value: `" ~
                            assignment.value.value.typeName ~ "` for field `" ~ assignment.ident.value ~ "`");
                    result.ok = false;
                }
            }
            else {
                result.diagnostics ~= Diagnostic(DiagnosticKind.UnknownElement, Severity.Error, assignment.ident.loc, "Undefined element `" ~ parts[0] ~ "`");
                result.ok = false;
            }
            // writeln("Assignment succeeded: ", assignment);
        }

        result.value = toSlide;

        return result;
    }

    Result!(slides.Master) buildMaster(ast.Master fromMaster) {
        Result!(slides.Master) result = Result!(slides.Master)(ok: true);

        slides.Master toMaster = new slides.Master(fromMaster.name, fromMaster.columns, fromMaster
                .rows);
        // build master items
        foreach (fromItem; fromMaster.items) {
            Result!(slides.Item) res = buildItem(fromItem);
            result.absorb(res);
            toMaster.items ~= res.value;
            toMaster.itemsMap[res.value.name] = res.value;
        }
        // copy master values
        toMaster.columns = fromMaster.columns;
        toMaster.rows = fromMaster.rows;
        fromMaster.background.match!(
            (RgbColour c) { toMaster.background = c; },
            (ast.Image i) {
            toMaster.background = new slides.Image("backgroundimage", i.path);
        }
        );

        result.value = toMaster;
        return result;
    }

    Result!(slides.Item) buildItem(ast.Item fromItem) {
        slides.Item toItem = fromItem.shape.match!(
            (ast.Rect r) => cast(slides.Item) new slides.Rect(fromItem.name, r.fill),
            (ast.Text t) => new slides.Text(fromItem.name, t.content, t.colour, t.size),
            (ast.Image i) => new slides.Image(fromItem.name, i.path),
            (ast.Movie m) => new slides.Movie(fromItem.name, m.path),
        );

        toItem.layoutLocation = fromItem.layoutLocation;

        return Result!(slides.Item)(ok: true, value: toItem);
    }

}
