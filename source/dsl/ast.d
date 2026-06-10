module dsl.ast;

import std.algorithm.iteration;
import std.array;
import std.conv;
import std.datetime;
import std.meta;
import std.sumtype;
import std.typecons;
import std.variant;

public import types;
import dsl.parser;
import types;

// TODO: move this to parser.d
alias DslTypes = AliasSeq!(
    string,
    int,
    float,
    bool,
    Identifier,
    QualifiedIdentifier,
    RichText,
    NamedColour,
    Alignment,
    Quantity,
    Date,
    FuncCall,
    DslArray,
);

// alias RichText = Typedef!(string, string.init, "richtext");
alias Seconds = Typedef!(int, int.init, "seconds");
alias Percent = Typedef!(ubyte, ubyte.init, "percent");
alias Centimeter = Typedef!(int, int.init, "centimeter");
alias Pixel = Typedef!(int, int.init, "pixel");
alias Fraction = Typedef!(ubyte, ubyte.init, "fraction");
alias Identifier = Typedef!(string, string.init, "identifier");

alias ColumnRow = SumType!(int, SlidexArray);

alias DslType = TaggedUnion!DslTypes;

struct TaggedUnion(V...) {

    this(T)(T v) {
        static foreach (i, U; V) {
            static if (is(T == U)) {
                kind = i;
                mixin("_" ~ i.stringof) = v;
                return;
            }
        }
    }

    size_t kind = size_t.max;
    private union {
        static foreach (i, T; V) {
            mixin("T _" ~ i.stringof ~ ";");
        }
    }

    template IndexOf(T, Types...) {
        enum IndexOf = IndexOfImpl!(T, Types);
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
        enum i = IndexOf!(T, V);
        static if (i == -1)
            static assert(false, "Type not in this TaggedUnion");

        return kind == i;
    }

    T get(T)() {
        enum i = IndexOf!(T, V);
        static if (i == -1)
            static assert(false, "Type not in this TaggedUnion");

        return mixin("_" ~ i.stringof);
    }

    Variant toVariant() {
        final switch (kind) {
            static foreach (i, T; V) {
        case i:
                return Variant(mixin("_" ~ i.stringof));
            }
        case size_t.max:
            break;
        }
        assert(false, "toVariant(): This TaggedUnion contains an unregistered kind.");
    }

    string toString() const {
        final switch (kind) {
            static foreach (i, T; V) {
        case i:
                static if (is(T == string))
                    return mixin("_" ~ i.stringof);
                else static if (is(T == bool))
                    return mixin("_" ~ i.stringof) ? "true" : "false";
                else
                    return mixin("_" ~ i.stringof).to!string;
            }
        case size_t.max:
            break;
        }
        assert(false, "toString(): This TaggedUnion contains an unregistered kind. This happens when no value was assigned.");
    }

    string typeName() {
        final switch (kind) {
            static foreach (i, T; V) {
        case i:
                return T.stringof;
            }
        case size_t.max:
            break;
        }
        assert(false, "typeName(): This TaggedUnion contains an unregistered kind. This happens when no value was assigned.");
    }

}

struct LocatedVal(T) {
    T value;
    SourceLocation loc;

    alias value this;

}

enum NamedColour {
    Red,
    Green,
    Blue,
    Cyan,
    Magenta,
    Yellow,
    White,
    Black,
}

enum Alignment {
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

struct Quantity {
    // TODO: Make distinction between int and float values
    LocatedVal!float value;
    LocatedVal!string unit;

    string toString() {
        return value.to!string ~ unit;
    }
}

struct DslArray {
    LocatedVal!DslType[] items;
}

LocatedVal!DslType locatedDslType(T)(T val, SourceLocation loc) {
    LocatedVal!DslType item;
    item.value = DslType(val);
    item.loc = loc;
    return item;
}

struct ArgList {
    NamedArg[string] namedArgs;
    LocatedVal!DslType[] positionalArgs;
}

struct NamedArg {
    LocatedVal!Identifier name;
    LocatedVal!DslType value;
}

struct QualifiedIdentifier {
    Identifier[] identifiers;

    bool opEquals(string)(const string ident) const {
        string[] parts = ident.split('.');
        if (parts.length != identifiers.length)
            return false;
        for (size_t i = 0; i < parts.length; ++i)
            if (parts[i] != identifiers[i])
                return false;
        return true;
    }

    ref Identifier opIndex(size_t index) {
        return identifiers[index];
    }

    string toString() const {
        return identifiers.map!(m=>cast(string)m).join('.');
    }
}

struct FuncCall {
    LocatedVal!Identifier name;
    ArgList arguments;
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

    // TODO: use field annotations for allowable
    ColumnRow columns;
    ColumnRow rows;

    SumType!(RgbColour, Image) background = RgbColour(0xff, 0xff, 0xff);

    string name;

    Item[string] itemsMap;
    Item[] items;
}

class Slide {

    string name;
    LocatedVal!string masterName;
    Master master;

    SequenceList sequencelist;

    Item[string] itemsMap;
    Item[] items;

    // assignments that should be resolved later
    ValueAssignment[] assignments;
}

alias Statement = SumType!(ValueAssignment, PropertyDeclaration);

struct ValueAssignment {
    // consider using a type for Qualified Identifier
    LocatedVal!QualifiedIdentifier ident;
    LocatedVal!DslType value;
}

struct PropertyDeclaration {
    LocatedVal!Identifier ident;
    LocatedVal!DslType value;
    LayoutLocation layoutLocation;
}

class Item {
    SourceLocation loc;
    string name;

    LayoutLocation layoutLocation;

    SumType!(Rect, Text, Image, Video) shape;

    this(string name) {
        this.name = name;
    }
}

struct Rect {
    RgbColour fill;
}

struct Text {
    RichText content;
    RgbColour colour;
    int size = 32; // default size
    // Alignment alignment = Alignment.TopLeft;
}

struct Image {
    string path;
}

struct Video {
    string path; // TODO: or URL
}

alias Event = SumType!(OnClickEvent, TimerEvent);

struct OnClickEvent {
    FuncCall func;

}

struct TimerEvent {
    Quantity quantity;
    FuncCall func;
}

struct SequenceList {
    Event[] events;
}

