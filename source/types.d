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

struct Point {
    float x;
    float y;
}

struct Size {
    float w;
    float h;
}

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
    TopCenter,
    TopRight,
    CenterLeft,
    Center,
    CenterRight,
    BottomLeft,
    BottomCenter,
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

class RichText {
    TextItem[] items;

    this() {
    }

    this(TextItem[] items) {
        this.items = items;
    }
}

alias TextItem = SumType!(Word, LineBreak, EscapedChar, Bold, Italic, Underline, Variable, Func, ListBlock, Code);

struct Word {
    string text;
}

struct EscapedChar {
    char letter;
}

alias Seconds = Typedef!(int, int.init, "seconds");

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

struct ListBlock {
    ListItem[] items;
}

struct ListItem {
    int level;
    char bullet;
    TextItem[] content;
}

struct Code {
    string[] lines;
}

struct LineBreak {
    string chars;
}
