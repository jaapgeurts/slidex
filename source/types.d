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


enum CellAlignment {
    TopLeft,
    Top,
    TopRight,
    Left,
    Center,
    Right,
    BottomLeft,
    Bottom,
    BottomRight
}

enum TextAlignment {
    Left,
    Center,
    Right
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

    CellAlignment alignment = CellAlignment.TopLeft;
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
    void visit(Variable variable);
    void visit(Func func);
    void visit(List list);
    void visit(Code code);
}

class RichText {
    TextItem[] items;
    private void applyVisitor(RichTextVisitor visitor, TextItem[] items) {
        foreach (item; items) {
            item.match!(
                (Word w) => visitor.visit(w),
                (Bold b) {
                visitor.enter(b);
                applyVisitor(visitor, b.items);
                visitor.leave(b);
            },
                (Italic i) {
                visitor.enter(i);
                applyVisitor(visitor, i.items);
                visitor.leave(i);
            },
                (Underline u) {
                visitor.enter(u);
                applyVisitor(visitor, u.items);
                visitor.leave(u);
            },
                (Variable v) => visitor.visit(v),
                (Func f) => visitor.visit(f),
                (List l) => visitor.visit(l),
                (Code c) => visitor.visit(c),
            );
        }
    }

    void accept(RichTextVisitor visitor) {
        visitor.visit(this);
        applyVisitor(visitor, items);
    }
}

alias TextItem = SumType!(Word, Bold, Italic, Underline, Variable, Func, List, Code);

struct Word {
    string text;
}

struct Bold {
    TextItem[] items;
}

struct Italic {
    TextItem[] items;
}

struct Underline {
    TextItem[] items;
}

struct Variable {
    string name;
}

struct Func {
    string name;
    // TODO: use union type. Not Variant.
    Variant[] args;
    TextItem[] items;
}

struct List {
    // TODO:
}

struct Code {
    string[] lines;
}
