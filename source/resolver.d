module resolver;

import std.array;
import std.stdio;
import std.sumtype;
import std.variant;

import ast;
import parser;
import slides;

ParseResult!(slides.Deck) resolveAst(ParseContext ctx, parser.Deck fromDeck) {
    // assert(false,__FUNCTION__ ~ "() not yet implemented.");
    ParseResult!(slides.Deck) result;

    slides.Deck toDeck = new slides.Deck();

    // build slides
    foreach (fromSlide; fromDeck.slides) {
        slides.Slide toSlide = new slides.Slide(fromSlide.name);
        // build master
        if (auto fromMaster = fromSlide.masterName.value in fromDeck.masterMap) {
            slides.Master toMaster = new slides.Master(fromMaster.name, fromMaster.columns, fromMaster
                    .rows);
            // build master items
            foreach (fromItem; fromMaster.items) {
                slides.Item toItem = fromItem.shape.match!(
                    (ast.Rect r) {
                    return cast(slides.Item) new slides.Rect(fromItem.name);
                },
                    (ast.Text t) { return new slides.Text(fromItem.name); },
                    (ast.Image i) { return new slides.Image(fromItem.name); });
                toMaster.items ~= toItem;
                toMaster.itemsMap[toItem.name] = toItem;
            }
            // copy master values
            toMaster.columns = fromMaster.columns;
            toMaster.rows = fromMaster.rows;
            toSlide.master = toMaster;

        }
        else {
            stderr.writeln(errorPrefix(fromSlide.masterName.loc), "ERROR: unknown master reference: " ~ fromSlide
                    .masterName.value);
        }
        ValueAssignment a;
        // apply deferred assignments
        foreach (assignment; fromSlide.assignments) {
            string[] parts = assignment.ident.value.split('.');

            // search items in master
            if (auto item = parts[0] in toSlide.master.itemsMap) {
                Variant var = assignment.value.value.toVariant;
                if (!item.hasProperty(parts[1])) {
                    // TODO: for correct location reporting increase the col location here with the length of the parts[1] 
                    stderr.writeln(errorPrefix(assignment.value.loc), "ERROR: no field `", parts[1], "` on element `", parts[0], "`");
                }
                else if (!item.isPropertyType(parts[1], var.type)) {
                    stderr.writeln(errorPrefix(assignment.value.loc), "ERROR: invalid type: `", assignment.value
                            .value.typeName, "` for field `", assignment.ident.value, "`");
                }
                else if (!item.setProperty(parts[1], var)) {
                    stderr.writeln(errorPrefix(assignment.value.loc), "ERROR: Couldn't set value: `", assignment.value
                            .value.typeName, "` for field `", assignment.ident.value, "`");
                }
            }
            else {
                stderr.writeln(errorPrefix(assignment.ident.loc), "ERROR: undefined element `", parts[0], "`");
            }
            writeln("Assignment succeeded: ", assignment);
        }

        // finally add the slide to the deck.
        toDeck.slides ~= toSlide;

    }

    result.ok = true;
    result.value = toDeck;
    return result;
}
