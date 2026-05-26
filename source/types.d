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


class RichText {
    TextItem[] items;
}

class TextItem {
}

class Word : TextItem {
    string text;
}

class Bold : TextItem {
    TextItem[] items;
}

class Italic : TextItem {
    TextItem[] items;
}

class Underline : TextItem {
    TextItem[] items;
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

