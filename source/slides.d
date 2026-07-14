module slides;

import std.sumtype;
import std.meta;
import std.traits;
import std.typecons;
import std.sumtype;
import std.variant;

import property;
import types;

// TODO: This can be removed later
mixin template DumpFieldsToString() {
    import std.array : appender;
    import std.conv : to;
    import std.traits : FieldNameTuple;
    import dsl.ast;

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
    void visit(Rect rect);
    void visit(Image image);
    void visit(Video video);
    void visit(Text text);
}

class ItemVisitorAdapter : ItemVisitor {
    // dfmt off
    void visit(Slide slide) {}
    void visit(Master master) {}
    void visit(Rect rect) {}
    void visit(Image image) {}
    void visit(Video video) {}
    void visit(Text text) {}
    // dfmt on
}

mixin template AcceptItemVisitorFunc() {
    override void accept(ItemVisitor visitor) {
        visitor.visit(this);
    }
}

class Deck {
    Slide[] slides;
    string rootpath;
}

enum DimensionUnit {
    Pixel,
    Fraction,
    Percent,
    Centimeter,
}

struct Length {
    float value;
    DimensionUnit unit;
}

alias IntOrLength = SumType!(int, Length[]);

template isValidPropertyType(T) {
    enum isValidPropertyType = staticIndexOf!(T, PropertyTypes) != -1;
}

mixin template DefineProperty(T, string name, T defaultval = T.init) {
    static assert(isValidPropertyType!T, "Property type " ~ T.stringof ~ " is not in PropertyTypes.");

    // registers the property in the dict at construction
    static this() {
        defaultProperties[name] = Property(defaultval);
    }

    // generate typed accessors
    mixin(T.stringof ~ " " ~ name ~ "() { return properties[\"" ~ name ~ "\"].match!((" ~ T.stringof ~ " v) => v, _ => " ~ T
            .stringof ~ ".init); }");

    mixin("void " ~ name ~ "(" ~ T.stringof ~ " val) { properties[name] = Property(val); }");

}

mixin template PropertyFunctions() {
    Property[string] properties;
    static Property[string] defaultProperties;

    Property getProperty(string name) {
        return properties[name];
    }

    bool setProperty(string name, Variant value) {
        Property* p = name in properties;
        if (p is null)
            return false;

        if (auto v = value.peek!TextAlignment)
            *p = Property(*v);
        else if (auto v = value.peek!string)
            *p = Property(*v);
        else if (auto v = value.peek!bool)
            *p = Property(*v);
        else if (auto v = value.peek!int)
            *p = Property(*v);
        else if (auto v = value.peek!float)
            *p = Property(*v);
        else if (auto v = value.peek!RichText)
            *p = Property(*v);
        else if (auto v = value.peek!RgbColour)
            *p = Property(*v);
        else
            return false;

        return true;
    }

    bool isPropertyType(string name, Variant t) {
        Property* p = name in properties;
        if (p is null)
            return false;

        return (*p).match!(
            // _ => false
                // static foreach(T;  PropertyTypes) {
                //         (T ) => t.type() == typeid(T),
                // }
                (TextAlignment ta) => t.type() == typeid(TextAlignment),
                (string s) => t.type() == typeid(string),
                (bool b) => t.type() == typeid(bool),
                (int i) => t.type() == typeid(int),
                (float f) => t.type() == typeid(float),
                (RichText rt) => t.type() == typeid(RichText),
                (RgbColour rc) => t.type() == typeid(RgbColour), // _ => false,

                

        );

    }

    bool hasProperty(string name) {
        return (name in properties) !is null;
    }
}

class Master {
    string name;

    IntOrLength columns;
    IntOrLength rows;

    /**
    Sets the background of this slide. Can be a:
    RgbColour(byte r,byte g, byte b) or an Image
    */
    SumType!(RgbColour, Image) background = RgbColour(0xff, 0xff, 0xff);

    Item[] items;
    Item[string] itemsMap;

    mixin DumpFieldsToString;

    /**
    Creates a new master slide.
    name: a unique name which identifies this master
    columns: an integer which specifies the number of columns or an array with column sizes
    rows: an integer which specifies the number of rows or an array with row sizes
    */
    this(string name, IntOrLength columns, IntOrLength rows) {
        this.name = name;
        this.columns = columns;
        this.rows = rows;
    }

    void accept(ItemVisitor visitor) {
        visitor.visit(this);
    }

}

class SlideState {

    Property[string] values;

    void put(T)(string obj, string key, T value) {
        values[obj ~ "." ~ key] = Property(value);
    }

    T get(T)(string obj, string key) {
        return values[obj ~ "." ~ key].match!((T v) => v, _ => T.init);
    }
}

class ApplyStateVisitor : ItemVisitor {

    SlideState state;

    this(SlideState state) {
        this.state = state;
    }

    void visit(Slide slide) {
    }

    void visit(Master master) {
    }

    void visit(Rect rect) {
        rect.visible = state.get!bool(rect.name, "visible");
    }

    void visit(Image image) {
        image.visible = state.get!bool(image.name, "visible");
    }

    void visit(Video video) {
        video.visible = state.get!bool(video.name, "visible");
    }

    void visit(Text text) {
        text.visible = state.get!bool(text.name, "visible");
    }

}

class GetStateVisitor : ItemVisitor {

    SlideState state;

    this() {
        state = new SlideState();
    }

    SlideState getState() {
        return state;
    }

    void visit(Slide slide) {
    }

    void visit(Master master) {
    }

    void visit(Rect rect) {
        state.put(rect.name, "visible", rect.visible);
    }

    void visit(Image image) {
        state.put(image.name, "visible", image.visible);
    }

    void visit(Video video) {
        state.put(video.name, "visible", video.visible);
    }

    void visit(Text text) {
        state.put(text.name, "visible", text.visible);
    }
}

class Slide {
    string name;

    Master master;

    Item[] items;
    Item[string] itemsMap;

    Event[] events;

    mixin PropertyFunctions;

    mixin DefineProperty!(RichText, "notes");

    this(string name) {
        this.name = name;
        this.properties = defaultProperties.dup;

    }

    // TODO: remove this later
    mixin DumpFieldsToString;

    void accept(ItemVisitor visitor) {
        visitor.visit(this);

        foreach (item; master.items)
            item.accept(visitor);
        foreach (item; items)
            item.accept(visitor);
    }

    SlideState getState() {
        GetStateVisitor visitor = new GetStateVisitor();
        accept(visitor);
        return visitor.getState();
    }

    void setState(SlideState state) {
        accept(new ApplyStateVisitor(state));
    }

}

class Item {
    string name;

    static Property[string] defaultProperties;
    mixin PropertyFunctions;
    mixin DefineProperty!(bool, "visible", true);

    LayoutLocation layoutLocation;

    this() {
        properties = defaultProperties.dup;
    }

    this(string name) {
        this();
        this.name = name;
    }

    abstract void accept(ItemVisitor visitor);

}

class Rect : Item {

    static Property[string] defaultProperties;
    mixin DefineProperty!(RgbColour, "fill");

    this(string name, RgbColour fill) {
        super(name);
        foreach (k, v; defaultProperties)
            properties[k] = v;

        this.fill = fill;
    }

    mixin AcceptItemVisitorFunc;
}

class Text : Item {

    static Property[string] defaultProperties;
    mixin DefineProperty!(RichText, "content");
    mixin DefineProperty!(RgbColour, "colour");
    mixin DefineProperty!(int, "size", 32);
    mixin DefineProperty!(TextAlignment, "alignment", TextAlignment.Left);

    this() {
        properties = defaultProperties.dup;
    }

    this(string name, RichText content, RgbColour colour, int size) {
        super(name);
        foreach (k, v; defaultProperties)
            properties[k] = v;

        this.content = content;
        this.colour = colour;
        this.size = size;
    }

    mixin AcceptItemVisitorFunc;
}

class Image : Item {
    static Property[string] defaultProperties;
    mixin DefineProperty!(string, "path");

    this(string name, string path) {
        super(name);
        foreach (k, v; defaultProperties)
            properties[k] = v;

        this.path = path;
    }

    mixin AcceptItemVisitorFunc;
}

class Video : Item {
    static Property[string] defaultProperties;
    mixin DefineProperty!(string, "path");

    this(string name, string path) {
        super(name);
        foreach (k, v; defaultProperties)
            properties[k] = v;

        this.path = path;
    }

    mixin AcceptItemVisitorFunc;
}

class Function {
    string name;
    // Variant[string] namedargs;
    Variant[] positionalargs;
}

abstract class Event {

    Function func;

}

class OnClickEvent : Event {
}

class TimerEvent : Event {
    int time;

    this(int time) {
        this.time = time;
    }
}
