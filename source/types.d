module types;

import core.exception;
import std.sumtype;
import std.typecons;
import std.variant;

struct SourceLocation {
    string filepath;
    ulong line;
    ulong column;
}

// enum Unit {
//     Unspecified,
//     Seconds,
//     Percent,
//     Fraction,
//     Centimeter,
//     Pixel,
// }

struct RgbColour {
    ubyte r;
    ubyte g;
    ubyte b;

    ubyte opIndex(size_t i) {
        if (i == 0)
            return r;
        else if (i == 1)
            return g;
        else if (i == 2)
            return b;
        else
            throw new ArrayIndexError(i, 3, "Valid indexes are 0,1,2 equivalent to r,g,b");
    }

    void opIndexAssign(ubyte val, size_t i) {
        if (i == 0)
            r = val;
        else if (i == 1)
            g = val;
        else if (i == 2)
            b = val;
        else
            throw new ArrayIndexError(i, 3, "Valid indexes are 0,1,2 equivalent to r,g,b");
    }

}

struct CellLocation {
    int col = 1;
    int row = 1;
    int colspan = 1;
    int rowspan = 1;
    // fine tuning
    int dx = 0;
    int dy = 0;
    // rotation
    float angle = 0;
}

struct BoundsLocation {
    int x = 10;
    int y = 10;
    int width = 100;
    int height = 100;
    // rotation
    float angle = 0;
}

alias LayoutLocation = SumType!(CellLocation, BoundsLocation);

interface RichTextVisitor {
    void visit(RichText richtext);
    void visit(TextItem textitem);
    void visit(Word word);
    void enter(Bold bold);
    void leave(Bold bold);
    void enter(Italic italic);
    void leave(Italic italic);
    void enter(Underline underline);
    void leave(Underline underline);
    void visit(Func func);
    void visit(List list);
    void visit(Code code);
}

class RichText {
    TextItem[] items;
    void accept(RichTextVisitor visitor) {
        visitor.visit(this);
        foreach (item; items) {
            item.accept(visitor);
        }
    }
}

abstract class TextItem {
    abstract void accept(RichTextVisitor visitor);
}

class Word : TextItem {
    string text;
    this(string text) {
        this.text = text;
    }

    override void accept(RichTextVisitor visitor) {
        visitor.visit(this);
    }
}

class Bold : TextItem {
    TextItem[] items;
    this() {
    }

    override void accept(RichTextVisitor visitor) {
        visitor.enter(this);
        foreach (item; items) {
            item.accept(visitor);
        }

        visitor.leave(this);
    }
}

class Italic : TextItem {
    TextItem[] items;
    override void accept(RichTextVisitor visitor) {
        visitor.enter(this);
        foreach (item; items) {
            item.accept(visitor);
        }

        visitor.leave(this);
    }
}

class Underline : TextItem {
    TextItem[] items;
    override void accept(RichTextVisitor visitor) {
        visitor.enter(this);
        foreach (item; items) {
            item.accept(visitor);
        }

        visitor.leave(this);
    }
}

class Func : TextItem {
    string name;
    // TODO: use union type. Not Variant.
    Variant[] args;
    TextItem[] items;
}

class List : TextItem {
    // TODO:
}

class Code : TextItem {
    string[] lines;
}
