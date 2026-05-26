module richtext.parser;

import std.stdio;

import pegged.grammar;

import types;
import common;

struct RichTextASTBuilder {

    string sourceFilePath;

public:

    // TODO: everywhere return Results so we can propagate errors
    Result!RichText buildRichText(ParseTree root) {
        Result!RichText result;

        writeln("ROOT: " ,root);

        return result;
    }

private:

}