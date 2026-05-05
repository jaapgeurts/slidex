module ast;

import std.datetime;
import std.meta;
import std.sumtype;
import std.conv;

struct Quantity {
    float value;
    string unit;
}

alias DslTypes = AliasSeq!(
    string,
    int,
    float,
    bool,
    Text,
    Colour,
    Quantity,
    Date
);

struct DslType {

    this(T)(T v) {
        static foreach (i, U; DslTypes) {
            static if (is(T == U)) {
                kind = i;
                mixin("_" ~ i.stringof) = v;
                return;
            }
        }
    }

    size_t kind = size_t.max;
    private union {
        static foreach (i, T; DslTypes) {
            mixin(T.stringof ~ " _" ~ i.stringof ~ ";");
        }
    }

    template IndexOf(T, Types...) {
        enum IndexOf = IndexOfImpl!(T, Types, 0);
    }

    template IndexOfImpl(T, Types...) {
        static if (Types.length == 0)
            enum IndexOfImpl = -1UL;
        else static if (is(T == Types[0]))
            enum IndexOfImpl = 0UL;
        else
            enum IndexOfImpl = 1UL + IndexOfImpl!(T, Types[1 .. $]);
    }

    bool has(T)() {
        enum i = IndexOf!(T, DslTypes);
        static if (i == -1)
            static assert(false, "Type not in DslTypes");

        return kind == i;
    }

    T get(T)() {
        enum i = IndexOf!(T, DslTypes);
        static if (i == -1)
            static assert(false, "Type not in DslTypes");

        return mixin("_" ~ i.stringof);
    }

    string toString() const {
        static foreach (i, T; DslTypes) {
            if (kind == i) {
                static if (is(T == string))
                    return mixin("_" ~ i.stringof);
                else static if (is(T == bool))
                    return mixin("_" ~ i.stringof) ? "true" : "false";
                else
                    return mixin("_" ~ i.stringof).to!string;
            }
        }
        assert(false, "toString not implemented for this type");
    }

    string typeName() {
        static foreach (i, T; DslTypes) {
            if (kind == i)
                return T.stringof;
        }
        return "unknown";
    }

}

struct SourceLocation {
    string filepath;
    ulong line;
    ulong column;
}

struct LocatedVal(T) {
    T value;
    SourceLocation loc;
}

enum Colour {
    Red,
    Green,
    Blue,
    Cyan,
    Magenta,
    Yellow,
}

class Deck {
    SourceLocation loc;

    string author;
    Date date;

    Master[] masters;
    Slide[] slides;

}

class Master {
    SourceLocation loc;

    uint columns;
    uint rows;

    string name;

    Item[string] itemsMap;
    Item[] items;
}

class Slide {
    SourceLocation loc;

    string name;
    string masterName;

    Event[] events;

    Item[string] itemsMap;
    Item[] items;
}

struct GridPos {
    uint col;
    uint row;
    uint colspan;
    uint rowspan;
    // fine tuning
    int dx;
    int dy;
    // rotation
    float rad;
}

struct AbsPos {
    uint x;
    uint y;
    uint width;
    uint height;
    // rotation
    float rad;
}

alias Position = SumType!(GridPos, AbsPos);

class Item {
    SourceLocation loc;
    Position position;
    string name;
}

class Rect : Item {
    Colour fill;
}

class Text : Item {
    string text;
}

class Image : Item {
    string path;
}

struct EventOnClick {
    LocatedVal!string func;
    DslType[string] args;
}

struct EventTimer {
    LocatedVal!Quantity quantity;
    LocatedVal!string func;
    DslType[string] args;
}

alias Event = SumType!(EventOnClick, EventTimer);
