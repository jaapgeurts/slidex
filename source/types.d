module types;

import std.sumtype;

struct SourceLocation {
    string filepath;
    ulong line;
    ulong column;
}

struct Quantity {
    float value;
    string unit;
}

enum Colour {
    Red,
    Green,
    Blue,
    Cyan,
    Magenta,
    Yellow,
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
