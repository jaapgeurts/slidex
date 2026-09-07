module slides;

import std.datetime;
import std.meta;
import std.stdio;
import std.sumtype;
import std.traits;
import std.typecons;
import std.variant;

import types;

alias BackgroundTypes = AliasSeq!(RgbColour, Image);
alias BackgroundType = SumType!(BackgroundTypes);

alias Int = Typedef!(int, int.init, "Int");
alias Float = Typedef!(float, float.init, "Float");
alias Bool = Typedef!(bool, bool.init, "Bool");

alias PropertyTypes = AliasSeq!(
    Int,
    Float,
    Bool,
    string,
    Date,
    RichText,
    RgbColour,
    TextAlignment,
    Rect,
    Text,
    Image,
    Video,
    BackgroundType,
);

alias PropertyType = SumType!PropertyTypes;

template TypeNameHandler(T) {
    string handler(T) {
        return T.stringof;
    }

    alias TypeNameHandler = handler;
}

string typeName(PropertyType value) {
    alias handlers = staticMap!(TypeNameHandler, PropertyType.Types);

    return value.match!handlers;
}

// Shared accessor type used by the property machinery — not itself mixed in.
struct PropertyAccessor {
    PropertyType delegate() get;
    void delegate(PropertyType) set;
}

// One-line "shared machinery" mixin: storage + auto-wiring constructor
mixin template PropertyContainer() {
    PropertyAccessor[string] properties;
    Variant[string] defaultProperties;

    void initProperties() {
        static foreach (member; __traits(allMembers, typeof(this))) {
            static if (member.length >= 12 && member[0 .. 12] == "__prop_init_")
                mixin("this." ~ member ~ "();");
        }
        // __propertiesWired = true;
    }

    // private bool __propertiesWired = false;
    // invariant {
    //     assert(__propertiesWired, "initProperties() was never called — "
    //             ~ "add 'initProperties();' as the first line of your constructor");
    // }

    bool hasProperty(string name) {
        return (name in properties) !is null;
    }

    bool setProperty(string name, PropertyType value) {
        if (!hasProperty(name))
            return false;
        properties[name].set(value);
        return true;
    }

    // Snapshot every registered property's current value.
    Variant[string] saveState() {
        Variant[string] state;
        foreach (name, accessor; properties)
            state[name] = accessor.get();
        return state;
    }

    // Restore values from a previous saveState() snapshot.
    // Unknown keys in `state` are silently ignored; missing keys are left untouched.
    void restoreState(PropertyType[string] state) {
        foreach (name, value; state) {
            if (auto accessor = name in properties)
                accessor.set(value);
        }
    }

    void savePropertyDefaults() {
        defaultProperties = saveState();
    }
}

// Builds the string for a SumType-aware setter: exact match on T,
// or wrap any of T's alternative types into T; anything else throws.
private string sumTypeSetterExpr(T)(string valueExpr) {
    string handlers = "(" ~ T.stringof ~ " exact) => exact, ";

    static foreach (Sub; TemplateArgsOf!T)
        handlers ~= "(" ~ Sub.stringof ~ " sub) => " ~ T.stringof ~ "(sub), ";

    handlers ~= " (other) => assert(false, \"Type mismatch assigning property: got \" ~ typeid(other).toString()),";

    // handlers ~= `(other) { throw new Exception(
    //     "Type mismatch assigning property: got " ~ typeid(other).toString()); }`;

    return valueExpr ~ ".match!(" ~ handlers ~ ")";
}

/++
 + Defines a typed, observable property on the host class and registers it
 + with the class's `properties` map for generic (name-based) access.
 +
 + Mixing this template in generates:
 + $(UL
 +   $(LI a private backing field `__prop_<name>` of type `T`, initialized
 +        to `defaultval`;)
 +   $(LI a public getter `T <name>()` and setter `void <name>(T val)` for
 +        fast, statically-typed access;)
 +   $(LI a `__prop_init_<name>()` hook, automatically discovered and
 +        invoked by `PropertyContainer.initProperties()`, which registers
 +        a `PropertyAccessor` for `<name>` in `properties`.)
 + )
 +
 + The generated `PropertyAccessor` exposes the field through `PropertyType`
 + (currently backed by `std.variant.Variant` or a `SumType`, depending on
 + configuration) so the value can be read or written generically via
 + `saveState()` / `restoreState()`, without callers needing to know `T`
 + at compile time.
 +
 + If `T` is an integer type such as int, float, bool, enums, etc, then
 + use or create a Typedef!(T) for it.
 +
 + Type aliases for use as `SumType` alternatives / property types in place
 + of certain built-in D types.
 +
 + `SumType`'s `match!` dispatches on the exact static type held, and D's
 + native `int`, `float`, and `bool` don't play well with that: they're
 + subject to implicit conversions and overload ambiguities (e.g. `bool`
 + converting to `int`, or an integer literal matching multiple numeric
 + handlers at once), which can make `match!` pick the wrong handler or
 + refuse to compile at all. Wrapping them in a distinct `Typedef` gives
 + each one its own concrete type, so `match!` (and the property setter's
 + type-matching logic) can distinguish them unambiguously.
 +
 + Use these instead of the native types wherever a property's `T` is used
 + as a `SumType` alternative:
 +
 + If `T` is a `SumType`, the generated setter also accepts any of `T`'s
 + alternative types directly and wraps them into `T` automatically —
 + assigning a bare alternative behaves the same as assigning a full `T`
 + holding that alternative. Assigning any other type throws.
 +
 + Params:
 +   T          = the property's value type. May be a plain type or a
 +                `std.sumtype.SumType`.
 +   name       = the property's identifier, used both as the D member
 +                name (`slide.title`) and as its string key in `properties`
 +                (`slide.properties["title"]`). Must be a valid D
 +                identifier.
 +   defaultval = the value the property holds before anything sets it.
 +                Defaults to `T.init`.
 +
 + Note:
 +   Requires `mixin PropertyContainer;` (or equivalent) in the same class
 +   to supply `properties`, `PropertyAccessor`, `PropertyType`, and
 +   `initProperties()`. The host class's constructor must call
 +   `initProperties();` before any property is used, or the
 +   `PropertyContainer` invariant will fail.
 +
 + Example:
 + ---
 + class Slide
 + {
 +     mixin PropertyContainer;
 +     mixin DefineProperty!(string, "title");
 +     mixin DefineProperty!(Int, "order", Int(1));
 +
 +     this(string title)
 +     {
 +         initProperties();
 +         this.title = title;
 +     }
 + }
 +
 + auto slide = new Slide("Intro");
 + slide.order = 2;                 // typed access
 + auto snap = slide.saveState();   // generic snapshot
 + slide.order = 99;
 + slide.restoreState(snap);        // slide.order == 2 again
 + ---
 +/
mixin template DefineProperty(T, string name, T defaultval = T.init) {
    mixin("private " ~ T.stringof ~ " __prop_" ~ name ~ " = defaultval;");

    static if (isSumType!T) {
        mixin("private void __prop_init_" ~ name ~ "() { properties[\"" ~ name
                ~ "\"] = PropertyAccessor(() => PropertyType(__prop_" ~ name
                ~ "), (PropertyType v) { __prop_" ~ name ~ " = " ~ sumTypeSetterExpr!T(
                    "v") ~ "; });}");
    }
    else {
        mixin("private void __prop_init_" ~ name ~ "() {properties[\"" ~ name
                ~ "\"] = PropertyAccessor(() => PropertyType(__prop_" ~ name
                ~ "),(PropertyType v) { __prop_" ~ name ~ " = v.get!(" ~ T.stringof ~ "); });}");
    }

    mixin(T.stringof ~ " " ~ name ~ "() { return __prop_" ~ name ~ "; }");
    mixin("void " ~ name ~ "(" ~ T.stringof ~ " val) { __prop_" ~ name ~ " = val; }");
}

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

class Master {
    string name;

    IntOrLength columns;
    IntOrLength rows;

    /**
    Sets the background of this slide. Can be a:
    RgbColour(byte r,byte g, byte b) or an Image
    */
    // TODO: Convert to property
    BackgroundType background = RgbColour(0x00, 0xff, 0xff);

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
        values[obj ~ "." ~ key] = value;
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
        rect.visible = state.get!Bool(rect.name, "visible");
    }

    void visit(Image image) {
        image.visible = state.get!Bool(image.name, "visible");
    }

    void visit(Video video) {
        video.visible = state.get!Bool(video.name, "visible");
    }

    void visit(Text text) {
        text.visible = state.get!Bool(text.name, "visible");
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

    mixin PropertyContainer;

    mixin DefineProperty!(BackgroundType, "background", BackgroundType(RgbColour(0xff, 0xff, 0xff)));
    mixin DefineProperty!(RichText, "notes");

    this(string name) {
        initProperties();
        this.name = name;

        savePropertyDefaults();
    }

    // TODO: remove this later
    mixin DumpFieldsToString;

    void accept(ItemVisitor visitor) {
        visitor.visit(this);

        if (master) {
            foreach (item; master.items)
                item.accept(visitor);
        }
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

    mixin PropertyContainer;
    mixin DefineProperty!(Bool, "visible", Bool(true));

    LayoutLocation layoutLocation;

    this() {
        initProperties();

        savePropertyDefaults();
    }

    this(string name) {
        this();
        this.name = name;
    }

    abstract void accept(ItemVisitor visitor);

}

class Rect : Item {

    mixin DefineProperty!(RgbColour, "fill");

    this(string name, RgbColour fill) {
        super(name);

        this.fill = fill;

        savePropertyDefaults();
    }

    mixin AcceptItemVisitorFunc;
}

class Text : Item {

    mixin DefineProperty!(RichText, "content");
    mixin DefineProperty!(RgbColour, "colour");
    mixin DefineProperty!(Int, "size", Int(32));
    mixin DefineProperty!(TextAlignment, "alignment", TextAlignment.Left);

    this(string name, RichText content, RgbColour colour, int size) {
        super(name);

        this.content = content;
        this.colour = colour;
        this.size = Int(size);

        savePropertyDefaults();
    }

    mixin AcceptItemVisitorFunc;
}

class Image : Item {

    mixin DefineProperty!(string, "path");

    this(string name, string path) {
        super(name);

        this.path = path;

        savePropertyDefaults();
    }

    mixin AcceptItemVisitorFunc;
}

class Video : Item {

    mixin DefineProperty!(string, "path");

    this(string name, string path) {
        super(name);

        this.path = path;

        savePropertyDefaults();
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
