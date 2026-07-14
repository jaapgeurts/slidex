module property;

import std.meta;
import std.sumtype;

import types;

alias PropertyTypes = AliasSeq!(
    string,
    int,
    float,
    bool,
    RichText,
    RgbColour,
    TextAlignment,
);

alias Property = SumType!PropertyTypes;
