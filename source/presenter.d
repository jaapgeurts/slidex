module presenter;

import std.stdio;

import slides;

void presentDeck(Deck deck) {
    writeln("DECK: ", deck.slides[0].name);
    writeln("DECK: ", deck.slides[0].master.items[0].visible);
}
