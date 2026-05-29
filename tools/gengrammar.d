module gengrammar;

import pegged.grammar;

int main(string[] args) {
    asModule("slxgrammar","slxgrammar",import("grammar.peg"));
    return 0;
}

