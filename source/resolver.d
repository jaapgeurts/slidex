module resolver;

import parser;
import slides;

ParseResult!(slides.Deck) resolveAst(ParseContext ctx, parser.Deck deck){
    assert(false,__FUNCTION__ ~ "() not yet implemented.");
    ParseResult!(slides.Deck) result;
    result.ok = true;
    result.value = new slides.Deck();
    return result;
}