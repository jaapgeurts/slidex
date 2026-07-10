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

mixin template ItemAcceptVisitor() {
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

    Variant[string] values;

    void put(T)(string obj, string key, T value) {
        values[obj ~ "." ~ key] = Variant(value);
    }

    T get(T)(string obj, string key) {
        return values[obj ~ "." ~ key].get!T;
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

    RichText speakerNotes;

    this(string name) {
        this.name = name;
        speakerNotes = new RichText();
    }

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

    override Variant[string] getState() {
        Variant[string] state;
        static foreach (member; __traits(allMembers, typeof(this))) {
            static if (hasUDA!(__traits(getMember, typeof(this), member), DslField)) {
                state[member.stringof] = Variant(__traits(getMember, this, member));
            }
        }
        return state;
    }

    override void setState(Variant[string] state) {
        foreach (key, value; state) {
            setProperty(key, value);
        }
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

    abstract Variant[string] getState();
    abstract void setState(Variant[string] state);

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

    @DslField
    TextAlignment alignment = TextAlignment.Left;

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
