module ast;

import std.conv;
import std.datetime;
import std.meta;
import std.sumtype;
import std.variant;

import types;

alias DslTypes = AliasSeq!(
    string,
    int,
    float,
    bool,
    Text,
    Colour,
    Quantity,
    Date,
    FuncCall
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

    Variant toVariant() {
        final switch (kind) {
            static foreach (i, T; DslTypes) {
        case i:
                return Variant(mixin("_" ~ i.stringof));
            }
        }
        assert(false, "toVariant(): This DslType contains an unregistered kind.");
    }

    string toString() const {
        final switch (kind) {
            static foreach (i, T; DslTypes) {
        case i:
                static if (is(T == string))
                    return mixin("_" ~ i.stringof);
                else static if (is(T == bool))
                    return mixin("_" ~ i.stringof) ? "true" : "false";
                else
                    return mixin("_" ~ i.stringof).to!string;
            }
        }
        assert(false, "toString(): This DslType contains an unregistered kind.");
    }

    string typeName() {
        final switch (kind) {
            static foreach (i, T; DslTypes) {
        case i:
                return T.stringof;
            }
        }
        assert(false, "typeName(): This DslType contains an unregistered kind.");
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

    alias value this;

}

LocatedVal!DslType locatedDslType(T)(T val, SourceLocation loc) {
    LocatedVal!DslType item;
    item.value = DslType(val);
    item.loc = loc;
    return item;
}

struct NamedArg {
    LocatedVal!string name;
    LocatedVal!DslType value;
}

struct FuncCall {
    LocatedVal!string name;
    NamedArg[string] namedArgs;
    LocatedVal!DslType[] positionalArgs;
}

class Deck {
    SourceLocation loc;

    string author;
    Date date;

    Master[string] masterMap;
    Master[] masters;
    Slide[string] slideMap;
    Slide[] slides;

}

class Master {
    SourceLocation loc;

    int columns;
    int rows;

    string name;

    Item[string] itemsMap;
    Item[] items;
}

class Slide {
    SourceLocation loc;

    string name;
    LocatedVal!string masterName;
    Master master;

    Event[] events;

    Item[string] itemsMap;
    Item[] items;

    // assignments that should be resolved later
    ValueAssignment[] assignments;
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

alias Statement = SumType!(ValueAssignment, PropertyDeclaration);

struct ValueAssignment {
    // consider using a type for Qualified Identifier
    LocatedVal!string ident;
    LocatedVal!DslType value;
}

struct PropertyDeclaration {
    LocatedVal!string ident;
    LocatedVal!DslType value;
    LayoutLocation layoutLocation;
}

class Item {
    SourceLocation loc;
    string name;

    LayoutLocation layoutLocation;

    SumType!(Rect, Text, Image) shape;

    this(string name) {
        this.name = name;
    }
}

struct Rect {
    Colour fill;
}

struct Text {
    string text;
}

struct Image {
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
