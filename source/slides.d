module slides;

import std.traits;
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
    void visit(Text text);
}

mixin template ItemAcceptVisitor() {
    override void accept(ItemVisitor visitor) {
        visitor.visit(this);
    }
}

struct Result(T) {
    T value;
    bool ok;
    string[] errors;
}

class Deck {
    Slide[] slides;

}

class Master {
    string name;

    uint columns;
    uint rows;

    Item[] items;
    Item[string] itemsMap;

    mixin DumpFieldsToString;

    this(string name, uint columns, uint rows) {
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
    
    @DslField
    Colour background;

    Master master;

    Item[] items;
    Item[string] itemsMap;

    this(string name) {
        this.name = name;
    }

    mixin DumpFieldsToString;

    void accept(ItemVisitor visitor) {
        visitor.visit(this);
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

    override bool isPropertyType(string name, TypeInfo info) {
        switch (name) {
            static foreach (member; __traits(allMembers, typeof(this))) {
                static if (hasUDA!(__traits(getMember, typeof(this), member), DslField)) {
        case member:
                    enum FT = typeid(typeof(__traits(getMember, typeof(this), member)));
                    return info is FT;
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
    abstract bool isPropertyType(string name, TypeInfo info);
    abstract bool setProperty(string name, Variant value);

    abstract void accept(ItemVisitor visitor);

}

class Rect : Item {

    @DslField
    Colour fill;

    this(string name) {
        super(name);
    }

    mixin DslProperties;

    mixin ItemAcceptVisitor;
}

class Text : Item {

    @DslField
    string body;

    this(string name) {
        super(name);
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
