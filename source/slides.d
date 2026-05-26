module slides;

import std.sumtype;
import std.traits;
import std.typecons;
import std.sumtype;
import std.variant;

import types;

// TODO: This can be removed later
mixin template DumpFieldsToString() {
    import std.array : appender;
    import std.conv : to;
    import std.traits : FieldNameTuple;

    override string toString() const {
        auto result = appender!string;

        result ~= typeof(this).stringof;
        result ~= "(";

        bool first = true;

        static foreach (name; FieldNameTuple!(typeof(this))) {
            {
                if (!first)
                    result ~= ", ";

                first = false;

                result ~= name;
                result ~= "=";

                alias FieldType =
                    typeof(__traits(getMember, this, name));

                static if (is(FieldType == class)) {
                    auto value = __traits(getMember, this, name);

                    if (value is null)
                        result ~= "null";
                    else
                        result ~= FieldType.stringof;
                }
                else {
                    result ~= to!string(
                        __traits(getMember, this, name)
                    );
                }
            }
        }

        result ~= ")";
        return result.data;
    }
}

interface ItemVisitor {
    void visit(Slide slide);
    void visit(Master master);
    void visit(Item item);
    void visit(Rect rect);
    void visit(Image image);
    void visit(Video video);
    void visit(Text text);
}

mixin template ItemAcceptVisitor() {
    override void accept(ItemVisitor visitor) {
        visitor.visit(this);
    }
}

class Deck {
    Slide[] slides;

}

enum DimensionUnit {
    Pixel,
    Fraction,
    Percent,
    Centimeter,
}

struct Length{
    float value;
    DimensionUnit unit;
}

alias IntOrLength = SumType!(int, Length[]);

class Master {
    string name;

    IntOrLength columns;
    IntOrLength rows;

    SumType!(RgbColour, Image) background = RgbColour(0xff, 0xff, 0xff);

    Item[] items;
    Item[string] itemsMap;

    mixin DumpFieldsToString;

    this(string name, IntOrLength columns, IntOrLength rows) {
        this.name = name;
        this.columns = columns;
        this.rows = rows;
    }

    void accept(ItemVisitor visitor) {
        visitor.visit(this);
    }

}

class Slide {
    string name;

    Master master;

    Item[] items;
    Item[string] itemsMap;

    this(string name) {
        this.name = name;
    }

    mixin DumpFieldsToString;

    void accept(ItemVisitor visitor) {
        visitor.visit(this);

        foreach (item; master.items)
            item.accept(visitor);
        foreach (item; items)
            item.accept(visitor);
    }

}

// This struct is for field annotations
struct DslField {
}

mixin template DslProperties() {
    override bool hasProperty(string name) {
        switch (name) {
            static foreach (member; __traits(allMembers, typeof(this))) {
                static if (hasUDA!(__traits(getMember, typeof(this), member), DslField)) {
        case member:
                    return true;
                }
            }
        default:
            return false;
        }
    }

    override bool isPropertyType(string name, Variant var) {
        switch (name) {
            static foreach (member; __traits(allMembers, typeof(this))) {
                static if (hasUDA!(__traits(getMember, typeof(this), member), DslField)) {
        case member: {
                        alias FT = typeof(__traits(getMember, typeof(this), member));
                        return var.convertsTo!(FT);
                    }
                }
            }
        default:
            return false;
        }
    }

    override bool setProperty(string name, Variant value) {

        switch (name) {
            static foreach (member; __traits(allMembers, typeof(this))) {
                static if (hasUDA!(__traits(getMember, typeof(this), member), DslField)) {
        case member:
                    alias FT = typeof(__traits(getMember, typeof(this), member));
                    __traits(getMember, this, member) = value.get!FT;
                    return true;
                }
            }
            break;
        default:
        }
        return false;
    }
}

class Item {
    string name;

    @DslField
    bool visible = true;

    LayoutLocation layoutLocation;

    this(string name) {
        this.name = name;
    }

    abstract bool hasProperty(string name);
    abstract bool isPropertyType(string name, Variant info);
    abstract bool setProperty(string name, Variant value);

    abstract void accept(ItemVisitor visitor);

}

class Rect : Item {

    @DslField
    RgbColour fill;

    this(string name, RgbColour fill) {
        super(name);
        this.fill = fill;
    }

    mixin DslProperties;

    mixin ItemAcceptVisitor;
}

class Text : Item {

    @DslField
    RichText content;

    @DslField
    RgbColour colour;

    @DslField
    int size = 32; // default font size

    this(string name, RichText content, RgbColour colour, int size) {
        super(name);
        this.content = content;
        this.colour = colour;
        this.size = size;

    }

    mixin DslProperties;

    mixin ItemAcceptVisitor;
}

class Image : Item {
    @DslField
    string path;

    this(string name, string path) {
        super(name);
        this.path = path;
    }

    mixin DslProperties;

    mixin ItemAcceptVisitor;
}

class Video : Item {
    @DslField
    string path;

    this(string name, string path) {
        super(name);
        this.path = path;
    }

    mixin DslProperties;

    mixin ItemAcceptVisitor;
}
