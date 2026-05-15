module common;

import std.string;
import std.stdio;

import types;

/* Possible diag kinds:
Lexer/Parser:

UnexpectedToken
UnexpectedEof
InvalidNumber
InvalidDate
UnterminatedString
UnterminatedText

Structure:

DuplicateDeclaration — same name declared twice in a block
UnknownBlockType — unknown keyword where master/slide expected

Properties:

UnknownProperty — background.banana = ...
TypeMismatch — wrong value type for property
MissingRequiredProperty — required field never assigned
InvalidUnit — 10banana

References:

UnresolvedMaster — slide references unknown master
UnresolvedItem — title.body but title never declared
UnresolvedEvent — event references undeclared item

Placement:

InvalidGridCoordinate — col/row out of bounds
ConflictingPlacement — both grid and absolute specified

Warnings:

UnusedDeclaration — item declared but never referenced
OverriddenProperty — property set twice in same block
*/

enum DiagnosticKind {
    DuplicateDeclaration,
    InvalidGridCoordinate,
    OverriddenProperty,
    InvalidType,
    UnknownProperty,
    UnknownElement,
    UnknownArgument,
    UnresolvedElement,
    UnresolvedMaster,
    UnusedDeclaration,
    ParseError,
    NameMismatch,
}

// enum DiagnosticKindMessage = [
//         "Duplicate declaration",
//         "Invalid grid coordinate",
//         "Overriden property",
//         "Invalid type",
//         "Unknown property",
//         "Unknown element",
//         "Unresolved element",
//         "Unresolved master",
//         "Unused declaration",
//         "Unexpected symbol",
//     ];

enum Severity {
    Error,
    Warning,
}

private string[] severityMsg = ["Error", "Warning"];

struct Diagnostic {
    DiagnosticKind kind;
    Severity severity;
    SourceLocation loc;
    string message;
}

struct Result(T = void) {
    /// cummulative errors and warnings
    Diagnostic[] diagnostics;
    // last parse result.
    bool ok;
    static if (!is(T == void)) {
        T value;
    }

    void absorb(U)(Result!U res) {
        diagnostics ~= res.diagnostics;
    }

}

alias VoidResult = Result!void;

// void printError(R)(const Diagnostic diagnostic, R sink) if (isOutputRange!(R, char)) {
void printError(const Diagnostic diagnostic,File file )  {
    // TODO: change concat to appender
    string message = format("%s:(%u,%u): %s: %s",
        diagnostic.loc.filepath,
        diagnostic.loc.line + 1,
        diagnostic.loc.column + 1,
        severityMsg[diagnostic.severity],
        diagnostic.message);
    file.writeln(message);
}

