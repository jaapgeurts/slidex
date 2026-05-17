module common;

import std.string;
import std.stdio;

import types;

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
    string message = format("%s:(%u,%u): %s: %s",
        diagnostic.loc.filepath,
        diagnostic.loc.line + 1,
        diagnostic.loc.column + 1,
        severityMsg[diagnostic.severity],
        diagnostic.message);
    file.writeln(message);
}
