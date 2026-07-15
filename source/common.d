module common;

import std.string;
import std.stdio;

import types;

struct Config {
    bool debug_;
    bool verbose;
    uint slidenum;
    uint monitornum;
    bool showpresenter;
    bool watch;
}

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
    InvalidUnit,
    InvalidValue,
    // Special error
    GeneralError,
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

enum AnsiRed = "\x1b[1;31m";
enum AnsiYellow = "\x1b[1;33m";
enum AnsiClear = "\x1b[0m";

private string[] severityMsg = [
    AnsiRed ~ "Error" ~ AnsiClear, AnsiYellow ~ "Warning" ~ AnsiClear
];

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

    struct Some(V) {
        V a;
        void ifSome(void delegate(V a) func) {
            func(a);
        }
    }

    auto absorb(U)(Result!U res) {
        if (!res.ok)
            ok = false;
        diagnostics ~= res.diagnostics;
        static if (!is(U == void)) {
            return Some!U(res.value);
        }
    }
}

alias VoidResult = Result!void;

// void printError(R)(const Diagnostic diagnostic, R sink) if (isOutputRange!(R, char)) {
void printError(const Diagnostic diagnostic, File file) {
    // TODO: change concat to appender
    string message = format("%s:(%u,%u): %s\x1b[0m: %s",
        diagnostic.loc.filepath,
        diagnostic.loc.line + 1,
        diagnostic.loc.column + 1,
        severityMsg[diagnostic.severity],
        diagnostic.message);
    file.writeln(message);
}

ubyte[] fromHex(scope const(char)[] s) {
    import std.array;
    import std.conv;

    if (s.length % 2 != 0)
        throw new Exception("Invalid hex input string. Odd number of characters");

    auto buf = appender!(ubyte[])();

    foreach (i; 0 .. s.length / 2) {
        auto byteStr = s[i * 2 .. i * 2 + 2];
        buf.put(cast(ubyte) to!uint(byteStr, 16));
    }

    return buf.data;
}
