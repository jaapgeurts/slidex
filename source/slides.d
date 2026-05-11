module slides;

import std.traits;
import std.variant;

import types;

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

    this(string name, uint columns, uint rows) {
        this.name = name;
        this.columns = columns;
        this.rows = rows;
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

    this(string name) {
        this.name = name;
    }

    abstract bool hasProperty(string name);
    abstract bool isPropertyType(string name, TypeInfo info);
    abstract bool setProperty(string name, Variant value);

}

class Rect : Item {

    @DslField
    Colour fill;

    this(string name) {
        super(name);
    }

    mixin DslProperties;
}

class Text : Item {

    @DslField
    string body;

    this(string name) {
        super(name);
    }

    mixin DslProperties;
}

class Image : Item {
    this(string name) {
        super(name);
    }

    mixin DslProperties;
}
