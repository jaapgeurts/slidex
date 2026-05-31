module gengrammar;

import std.file;

import pegged.grammar;

int main(string[] args) {
    asModule("slxgrammar","slxgrammar",readText("grammar.peg"));
    return 0;
}

