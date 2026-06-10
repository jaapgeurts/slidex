/+ DO NOT EDIT BY HAND!
This module was automatically generated from the following grammar:

# ──── Slide DSL ───────────────────────────────────
# Date: May 2026
# Author: Jaap Geurts
# Version: 0.3

SlidexDoc:

    SlideDeck           <-  WsComment Deck?  (Master / Slide )* eoi

# Deck
    Deck                <- DECK BEGIN DeckContent* END DECK

# Master
    Master              <- MASTER OpeningIdentifier BEGIN MasterContent END MASTER ClosingIdentifier

# Slide
    Slide               <- SLIDE OpeningIdentifier FROM MasterIdentifier BEGIN SlideContent* END SLIDE ClosingIdentifier

# DeckContent
    DeckContent         <- ValueAssignment SEMICOLON

# MasterContent
    MasterContent       <- Statement*

# Statement
    Statement           <- (PropertyDeclaration / ValueAssignment) SEMICOLON
    PropertyDeclaration <- (Identifier CREATE )? FuncCall Placement?
    ValueAssignment     <- QualifiedIdentifier EQUAL Value
    Placement           <- AT (CELL / BOUNDS) ArgList

# Slide Contents
    SlideContent        <- SequenceList / Statement

# Events
    SequenceList        <- SEQUENCE BEGIN Event* END SEQUENCE
    Event               <- EventType DO FuncCall SEMICOLON
    EventType           <- CLICKEVENT / TimerEvent
    TimerEvent          <- AFTER Quantity
    
# construction
    FuncCall            <- Identifier ArgList
    ArgList             <- LPAREN Args? RPAREN
    Args                <- Argument (COMMA Argument)* COMMA?
    Argument            <- NamedArg / PositionalArg
    NamedArg            <- Identifier EQUAL Value
    PositionalArg       <- Value

# General
    OpeningIdentifier   <- Identifier
    ClosingIdentifier   <- Identifier
    MasterIdentifier    <- Identifier

    Value               <- String / Array / Date / Quantity / RichText / Boolean / NamedColour / Alignment / FuncCall / QualifiedIdentifier

    Array               <- LSQUARE ArrayValues? RSQUARE
    ArrayValues         <- Value (COMMA Value)*
    Date                <~ [1-9][0-9][0-9][0-9] '-' [0-9][0-9] '-' [0-9][0-9] WsComment
    Number              <- '-'? Digits
    Quantity            <- Number Unit?
    Digits              <~ [0-9] [0-9]* WsComment
    Unit                <- ('s' / '%' / 'cm' / 'fr' / 'px') WsComment
    String              <- :doublequote ~(!doublequote .)* :doublequote WsComment
    RichText            <- :LBRACE :(space* eol)? RichTextNode* :RBRACE
    NamedColour         <- ('red' / 'green' / 'blue' / 'yellow' / 'cyan' / 'magenta' / 'white' / 'black') WsComment
    Alignment           <- ('topleft' / 'topcenter' / 'topright' / 'centerleft' / 'centerright' / 'center' / 'bottomleft' / 'bottomcenter' / 'bottomright' ) WsComment
    Boolean             <- ('true' / 'false' / 'yes' / 'no' / 'on' / 'off' ) WsComment

    Identifier          <- identifier WsComment
    QualifiedIdentifier <- identifier ('.' identifier)* WsComment

    DECK                <- 'deck'     WsComment
    MASTER              <- 'master'   WsComment
    SLIDE               <- 'slide'    WsComment
    FROM                <- 'from'     WsComment
    BEGIN               <- 'begin'    WsComment
    END                 <- 'end'      WsComment
    SEQUENCE            <- 'sequence' WsComment
    DO                  <- 'do'       WsComment
    CLICKEVENT          <- 'on' WsComment 'click' WsComment
    AFTER               <- 'after'    WsComment
    AT                  <- 'at'       WsComment
    CELL                <- 'cell'     WsComment
    BOUNDS              <- 'bounds'   WsComment
    LPAREN              <- '('        WsComment 
    RPAREN              <- ')'        WsComment
    LSQUARE             <- '['        WsComment
    RSQUARE             <- ']'        WsComment
    LBRACE              <- '{'  # Special case, after open brace, text content follows
    RBRACE              <- '}'        WsComment
    SEMICOLON           <: ';'        WsComment
    CREATE              <- ':='       WsComment
    EQUAL               <- '='        WsComment
    COMMA               <- ','        WsComment
    WsComment           <- (InlineComment / EolComment / :blank)*
    EolComment          <- '#' ~(!eol .)* :eol
    InlineComment       <- '/#' ~(!'#/' .)* '#/'


# ──── End Slide DSL ───────────────────────────────────


# ──── RichText ───────────────────────────────────────

## TODO: factor out these parts?
    RichTextNode        <-  LineBreak / EscapedChar / CodeBlock / ListBlock / Func / Bold / Italic / Underline / Strike / SmallCaps / Variable / Word / :space

# RichText Inline sugar

    Bold                <- '*' InlineContent '*'
    Italic              <- '/' InlineContent '/'
    Underline           <- '_' InlineContent '_'
    Strike              <- '~' InlineContent '~'
    SmallCaps           <- '#' InlineContent '#'

# RichText Variable 

    Variable            <- '$' identifier

# RichText Function call

    Func                <- '[' WS FuncName WS FuncArgs WS (':' WS InlineContent)? ']'
    FuncName            <- identifier
    FuncArgs            <- FuncArg? (',' FuncArg)*
    FuncArg             <- RTString / RTNumber / identifier

# # RichText Inline content (recursive)
    InlineContent       <- InlineNode*
    InlineNode          <-  LineBreak/ EscapedChar / Func / Bold / Italic / Underline / Strike / SmallCaps / Variable / InlineWord / :space

    ListItemContent     <- ListItemNode*
    ListItemNode        <-  EscapedChar / Func / Bold / Italic / Underline / Strike / SmallCaps / Variable / InlineWord / :space

#  RichText Lists

    ListBlock           <- ListItem+
    ListItem            <- (BulletMarker/NumberMarker) ListItemContent eol
    BulletMarker        <- ' '* '-' ' '+
    NumberMarker        <- ' '* [0-9]+ '.' ' '+

# RichText Code block

    CodeBlock           <- BACKTICKS identifier? :eol
                       CodeLine* 
                       BACKTICKS :eol?
    CodeLine            <~ (!BACKTICKS !eol .)* eol
    BACKTICKS           <~ backquote backquote backquote


# RichText Primitives

    Word                <~ (!SpecialChar !blank !eol .)+
    InlineWord          <~ (!InlineSpecial !blank !eol .)+

    SpecialChar         <- '\\' / '*' / '/' / '-' / '_' / '~' / '#' / '[' / '$' / backquote / '}' / blank / eol
    InlineSpecial       <- SpecialChar / ']'

    RTNumber            <~ [0-9]+
    RTString            <- :doublequote ~(!doublequote .)* :doublequote

    EscapedChar         <- '\\' . 
    LineBreak           <- endOfLine

    WS                  <- :blank*

+/
module slxgrammar;

public import pegged.peg;
import std.algorithm: startsWith;
import std.functional: toDelegate;

@safe struct GenericSlidexDoc(TParseTree)
{
    import std.functional : toDelegate;
    import pegged.dynamic.grammar;
    static import pegged.peg;
    struct SlidexDoc
    {
    enum name = "SlidexDoc";
    static ParseTree delegate(ParseTree) @safe [string] before;
    static ParseTree delegate(ParseTree) @safe [string] after;
    static ParseTree delegate(ParseTree) @safe [string] rules;
    import std.typecons:Tuple, tuple;
    static TParseTree[Tuple!(string, size_t)] memo;
    static this() @trusted
    {
        rules["SlideDeck"] = toDelegate(&SlideDeck);
        rules["Deck"] = toDelegate(&Deck);
        rules["Master"] = toDelegate(&Master);
        rules["Slide"] = toDelegate(&Slide);
        rules["DeckContent"] = toDelegate(&DeckContent);
        rules["MasterContent"] = toDelegate(&MasterContent);
        rules["Statement"] = toDelegate(&Statement);
        rules["PropertyDeclaration"] = toDelegate(&PropertyDeclaration);
        rules["ValueAssignment"] = toDelegate(&ValueAssignment);
        rules["Placement"] = toDelegate(&Placement);
        rules["SlideContent"] = toDelegate(&SlideContent);
        rules["SequenceList"] = toDelegate(&SequenceList);
        rules["Event"] = toDelegate(&Event);
        rules["EventType"] = toDelegate(&EventType);
        rules["TimerEvent"] = toDelegate(&TimerEvent);
        rules["FuncCall"] = toDelegate(&FuncCall);
        rules["ArgList"] = toDelegate(&ArgList);
        rules["Args"] = toDelegate(&Args);
        rules["Argument"] = toDelegate(&Argument);
        rules["NamedArg"] = toDelegate(&NamedArg);
        rules["PositionalArg"] = toDelegate(&PositionalArg);
        rules["OpeningIdentifier"] = toDelegate(&OpeningIdentifier);
        rules["ClosingIdentifier"] = toDelegate(&ClosingIdentifier);
        rules["MasterIdentifier"] = toDelegate(&MasterIdentifier);
        rules["Value"] = toDelegate(&Value);
        rules["Array"] = toDelegate(&Array);
        rules["ArrayValues"] = toDelegate(&ArrayValues);
        rules["Date"] = toDelegate(&Date);
        rules["Number"] = toDelegate(&Number);
        rules["Quantity"] = toDelegate(&Quantity);
        rules["Digits"] = toDelegate(&Digits);
        rules["Unit"] = toDelegate(&Unit);
        rules["String"] = toDelegate(&String);
        rules["RichText"] = toDelegate(&RichText);
        rules["NamedColour"] = toDelegate(&NamedColour);
        rules["Alignment"] = toDelegate(&Alignment);
        rules["Boolean"] = toDelegate(&Boolean);
        rules["Identifier"] = toDelegate(&Identifier);
        rules["QualifiedIdentifier"] = toDelegate(&QualifiedIdentifier);
        rules["DECK"] = toDelegate(&DECK);
        rules["MASTER"] = toDelegate(&MASTER);
        rules["SLIDE"] = toDelegate(&SLIDE);
        rules["FROM"] = toDelegate(&FROM);
        rules["BEGIN"] = toDelegate(&BEGIN);
        rules["END"] = toDelegate(&END);
        rules["SEQUENCE"] = toDelegate(&SEQUENCE);
        rules["DO"] = toDelegate(&DO);
        rules["CLICKEVENT"] = toDelegate(&CLICKEVENT);
        rules["AFTER"] = toDelegate(&AFTER);
        rules["AT"] = toDelegate(&AT);
        rules["CELL"] = toDelegate(&CELL);
        rules["BOUNDS"] = toDelegate(&BOUNDS);
        rules["LPAREN"] = toDelegate(&LPAREN);
        rules["RPAREN"] = toDelegate(&RPAREN);
        rules["LSQUARE"] = toDelegate(&LSQUARE);
        rules["RSQUARE"] = toDelegate(&RSQUARE);
        rules["LBRACE"] = toDelegate(&LBRACE);
        rules["RBRACE"] = toDelegate(&RBRACE);
        rules["SEMICOLON"] = toDelegate(&SEMICOLON);
        rules["CREATE"] = toDelegate(&CREATE);
        rules["EQUAL"] = toDelegate(&EQUAL);
        rules["COMMA"] = toDelegate(&COMMA);
        rules["WsComment"] = toDelegate(&WsComment);
        rules["EolComment"] = toDelegate(&EolComment);
        rules["InlineComment"] = toDelegate(&InlineComment);
        rules["RichTextNode"] = toDelegate(&RichTextNode);
        rules["Bold"] = toDelegate(&Bold);
        rules["Italic"] = toDelegate(&Italic);
        rules["Underline"] = toDelegate(&Underline);
        rules["Strike"] = toDelegate(&Strike);
        rules["SmallCaps"] = toDelegate(&SmallCaps);
        rules["Variable"] = toDelegate(&Variable);
        rules["Func"] = toDelegate(&Func);
        rules["FuncName"] = toDelegate(&FuncName);
        rules["FuncArgs"] = toDelegate(&FuncArgs);
        rules["FuncArg"] = toDelegate(&FuncArg);
        rules["InlineContent"] = toDelegate(&InlineContent);
        rules["InlineNode"] = toDelegate(&InlineNode);
        rules["ListItemContent"] = toDelegate(&ListItemContent);
        rules["ListItemNode"] = toDelegate(&ListItemNode);
        rules["ListBlock"] = toDelegate(&ListBlock);
        rules["ListItem"] = toDelegate(&ListItem);
        rules["BulletMarker"] = toDelegate(&BulletMarker);
        rules["NumberMarker"] = toDelegate(&NumberMarker);
        rules["CodeBlock"] = toDelegate(&CodeBlock);
        rules["CodeLine"] = toDelegate(&CodeLine);
        rules["BACKTICKS"] = toDelegate(&BACKTICKS);
        rules["Word"] = toDelegate(&Word);
        rules["InlineWord"] = toDelegate(&InlineWord);
        rules["SpecialChar"] = toDelegate(&SpecialChar);
        rules["InlineSpecial"] = toDelegate(&InlineSpecial);
        rules["RTNumber"] = toDelegate(&RTNumber);
        rules["RTString"] = toDelegate(&RTString);
        rules["EscapedChar"] = toDelegate(&EscapedChar);
        rules["LineBreak"] = toDelegate(&LineBreak);
        rules["WS"] = toDelegate(&WS);
        rules["Spacing"] = toDelegate(&Spacing);
    }

    template hooked(alias r, string name)
    {
        static ParseTree hooked(ParseTree p) @safe
        {
            ParseTree result;

            if (name in before)
            {
                result = before[name](p);
                if (result.successful)
                    return result;
            }

            result = r(p);
            if (result.successful || name !in after)
                return result;

            result = after[name](p);
            return result;
        }

        static ParseTree hooked(string input) @safe
        {
            return hooked!(r, name)(ParseTree("",false,[],input));
        }
    }

    static void addRuleBefore(string parentRule, string ruleSyntax) @safe
    {
        // enum name is the current grammar name
        DynamicGrammar dg = pegged.dynamic.grammar.grammar(name ~ ": " ~ ruleSyntax, rules);
        foreach(ruleName,rule; dg.rules)
            if (ruleName != "Spacing") // Keep the local Spacing rule, do not overwrite it
                rules[ruleName] = rule;
        before[parentRule] = rules[dg.startingRule];
    }

    static void addRuleAfter(string parentRule, string ruleSyntax) @safe
    {
        // enum name is the current grammar named
        DynamicGrammar dg = pegged.dynamic.grammar.grammar(name ~ ": " ~ ruleSyntax, rules);
        foreach(ruleName,rule; dg.rules)
        {
            if (ruleName != "Spacing")
                rules[ruleName] = rule;
        }
        after[parentRule] = rules[dg.startingRule];
    }

    static bool isRule(string s) pure nothrow @nogc
    {
        import std.algorithm : startsWith;
        return s.startsWith("SlidexDoc.");
    }
    mixin decimateTree;

    alias spacing Spacing;

    static TParseTree SlideDeck(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(WsComment, pegged.peg.option!(Deck), pegged.peg.zeroOrMore!(pegged.peg.or!(Master, Slide)), eoi), "SlidexDoc.SlideDeck")(p);
        }
        else
        {
            if (auto m = tuple(`SlideDeck`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(WsComment, pegged.peg.option!(Deck), pegged.peg.zeroOrMore!(pegged.peg.or!(Master, Slide)), eoi), "SlidexDoc.SlideDeck"), "SlideDeck")(p);
                memo[tuple(`SlideDeck`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree SlideDeck(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(WsComment, pegged.peg.option!(Deck), pegged.peg.zeroOrMore!(pegged.peg.or!(Master, Slide)), eoi), "SlidexDoc.SlideDeck")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(WsComment, pegged.peg.option!(Deck), pegged.peg.zeroOrMore!(pegged.peg.or!(Master, Slide)), eoi), "SlidexDoc.SlideDeck"), "SlideDeck")(TParseTree("", false,[], s));
        }
    }
    static string SlideDeck(GetName g)
    {
        return "SlidexDoc.SlideDeck";
    }

    static TParseTree Deck(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DECK, BEGIN, pegged.peg.zeroOrMore!(DeckContent), END, DECK), "SlidexDoc.Deck")(p);
        }
        else
        {
            if (auto m = tuple(`Deck`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(DECK, BEGIN, pegged.peg.zeroOrMore!(DeckContent), END, DECK), "SlidexDoc.Deck"), "Deck")(p);
                memo[tuple(`Deck`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Deck(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(DECK, BEGIN, pegged.peg.zeroOrMore!(DeckContent), END, DECK), "SlidexDoc.Deck")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(DECK, BEGIN, pegged.peg.zeroOrMore!(DeckContent), END, DECK), "SlidexDoc.Deck"), "Deck")(TParseTree("", false,[], s));
        }
    }
    static string Deck(GetName g)
    {
        return "SlidexDoc.Deck";
    }

    static TParseTree Master(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(MASTER, OpeningIdentifier, BEGIN, MasterContent, END, MASTER, ClosingIdentifier), "SlidexDoc.Master")(p);
        }
        else
        {
            if (auto m = tuple(`Master`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(MASTER, OpeningIdentifier, BEGIN, MasterContent, END, MASTER, ClosingIdentifier), "SlidexDoc.Master"), "Master")(p);
                memo[tuple(`Master`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Master(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(MASTER, OpeningIdentifier, BEGIN, MasterContent, END, MASTER, ClosingIdentifier), "SlidexDoc.Master")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(MASTER, OpeningIdentifier, BEGIN, MasterContent, END, MASTER, ClosingIdentifier), "SlidexDoc.Master"), "Master")(TParseTree("", false,[], s));
        }
    }
    static string Master(GetName g)
    {
        return "SlidexDoc.Master";
    }

    static TParseTree Slide(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(SLIDE, OpeningIdentifier, FROM, MasterIdentifier, BEGIN, pegged.peg.zeroOrMore!(SlideContent), END, SLIDE, ClosingIdentifier), "SlidexDoc.Slide")(p);
        }
        else
        {
            if (auto m = tuple(`Slide`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(SLIDE, OpeningIdentifier, FROM, MasterIdentifier, BEGIN, pegged.peg.zeroOrMore!(SlideContent), END, SLIDE, ClosingIdentifier), "SlidexDoc.Slide"), "Slide")(p);
                memo[tuple(`Slide`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Slide(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(SLIDE, OpeningIdentifier, FROM, MasterIdentifier, BEGIN, pegged.peg.zeroOrMore!(SlideContent), END, SLIDE, ClosingIdentifier), "SlidexDoc.Slide")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(SLIDE, OpeningIdentifier, FROM, MasterIdentifier, BEGIN, pegged.peg.zeroOrMore!(SlideContent), END, SLIDE, ClosingIdentifier), "SlidexDoc.Slide"), "Slide")(TParseTree("", false,[], s));
        }
    }
    static string Slide(GetName g)
    {
        return "SlidexDoc.Slide";
    }

    static TParseTree DeckContent(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ValueAssignment, SEMICOLON), "SlidexDoc.DeckContent")(p);
        }
        else
        {
            if (auto m = tuple(`DeckContent`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(ValueAssignment, SEMICOLON), "SlidexDoc.DeckContent"), "DeckContent")(p);
                memo[tuple(`DeckContent`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree DeckContent(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(ValueAssignment, SEMICOLON), "SlidexDoc.DeckContent")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(ValueAssignment, SEMICOLON), "SlidexDoc.DeckContent"), "DeckContent")(TParseTree("", false,[], s));
        }
    }
    static string DeckContent(GetName g)
    {
        return "SlidexDoc.DeckContent";
    }

    static TParseTree MasterContent(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(Statement), "SlidexDoc.MasterContent")(p);
        }
        else
        {
            if (auto m = tuple(`MasterContent`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(Statement), "SlidexDoc.MasterContent"), "MasterContent")(p);
                memo[tuple(`MasterContent`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree MasterContent(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(Statement), "SlidexDoc.MasterContent")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(Statement), "SlidexDoc.MasterContent"), "MasterContent")(TParseTree("", false,[], s));
        }
    }
    static string MasterContent(GetName g)
    {
        return "SlidexDoc.MasterContent";
    }

    static TParseTree Statement(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(PropertyDeclaration, ValueAssignment), SEMICOLON), "SlidexDoc.Statement")(p);
        }
        else
        {
            if (auto m = tuple(`Statement`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(PropertyDeclaration, ValueAssignment), SEMICOLON), "SlidexDoc.Statement"), "Statement")(p);
                memo[tuple(`Statement`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Statement(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(PropertyDeclaration, ValueAssignment), SEMICOLON), "SlidexDoc.Statement")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(PropertyDeclaration, ValueAssignment), SEMICOLON), "SlidexDoc.Statement"), "Statement")(TParseTree("", false,[], s));
        }
    }
    static string Statement(GetName g)
    {
        return "SlidexDoc.Statement";
    }

    static TParseTree PropertyDeclaration(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.and!(Identifier, CREATE)), FuncCall, pegged.peg.option!(Placement)), "SlidexDoc.PropertyDeclaration")(p);
        }
        else
        {
            if (auto m = tuple(`PropertyDeclaration`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.and!(Identifier, CREATE)), FuncCall, pegged.peg.option!(Placement)), "SlidexDoc.PropertyDeclaration"), "PropertyDeclaration")(p);
                memo[tuple(`PropertyDeclaration`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree PropertyDeclaration(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.and!(Identifier, CREATE)), FuncCall, pegged.peg.option!(Placement)), "SlidexDoc.PropertyDeclaration")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.and!(Identifier, CREATE)), FuncCall, pegged.peg.option!(Placement)), "SlidexDoc.PropertyDeclaration"), "PropertyDeclaration")(TParseTree("", false,[], s));
        }
    }
    static string PropertyDeclaration(GetName g)
    {
        return "SlidexDoc.PropertyDeclaration";
    }

    static TParseTree ValueAssignment(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(QualifiedIdentifier, EQUAL, Value), "SlidexDoc.ValueAssignment")(p);
        }
        else
        {
            if (auto m = tuple(`ValueAssignment`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(QualifiedIdentifier, EQUAL, Value), "SlidexDoc.ValueAssignment"), "ValueAssignment")(p);
                memo[tuple(`ValueAssignment`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ValueAssignment(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(QualifiedIdentifier, EQUAL, Value), "SlidexDoc.ValueAssignment")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(QualifiedIdentifier, EQUAL, Value), "SlidexDoc.ValueAssignment"), "ValueAssignment")(TParseTree("", false,[], s));
        }
    }
    static string ValueAssignment(GetName g)
    {
        return "SlidexDoc.ValueAssignment";
    }

    static TParseTree Placement(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(AT, pegged.peg.or!(CELL, BOUNDS), ArgList), "SlidexDoc.Placement")(p);
        }
        else
        {
            if (auto m = tuple(`Placement`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(AT, pegged.peg.or!(CELL, BOUNDS), ArgList), "SlidexDoc.Placement"), "Placement")(p);
                memo[tuple(`Placement`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Placement(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(AT, pegged.peg.or!(CELL, BOUNDS), ArgList), "SlidexDoc.Placement")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(AT, pegged.peg.or!(CELL, BOUNDS), ArgList), "SlidexDoc.Placement"), "Placement")(TParseTree("", false,[], s));
        }
    }
    static string Placement(GetName g)
    {
        return "SlidexDoc.Placement";
    }

    static TParseTree SlideContent(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(SequenceList, Statement), "SlidexDoc.SlideContent")(p);
        }
        else
        {
            if (auto m = tuple(`SlideContent`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(SequenceList, Statement), "SlidexDoc.SlideContent"), "SlideContent")(p);
                memo[tuple(`SlideContent`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree SlideContent(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(SequenceList, Statement), "SlidexDoc.SlideContent")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(SequenceList, Statement), "SlidexDoc.SlideContent"), "SlideContent")(TParseTree("", false,[], s));
        }
    }
    static string SlideContent(GetName g)
    {
        return "SlidexDoc.SlideContent";
    }

    static TParseTree SequenceList(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(SEQUENCE, BEGIN, pegged.peg.zeroOrMore!(Event), END, SEQUENCE), "SlidexDoc.SequenceList")(p);
        }
        else
        {
            if (auto m = tuple(`SequenceList`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(SEQUENCE, BEGIN, pegged.peg.zeroOrMore!(Event), END, SEQUENCE), "SlidexDoc.SequenceList"), "SequenceList")(p);
                memo[tuple(`SequenceList`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree SequenceList(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(SEQUENCE, BEGIN, pegged.peg.zeroOrMore!(Event), END, SEQUENCE), "SlidexDoc.SequenceList")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(SEQUENCE, BEGIN, pegged.peg.zeroOrMore!(Event), END, SEQUENCE), "SlidexDoc.SequenceList"), "SequenceList")(TParseTree("", false,[], s));
        }
    }
    static string SequenceList(GetName g)
    {
        return "SlidexDoc.SequenceList";
    }

    static TParseTree Event(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(EventType, DO, FuncCall, SEMICOLON), "SlidexDoc.Event")(p);
        }
        else
        {
            if (auto m = tuple(`Event`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(EventType, DO, FuncCall, SEMICOLON), "SlidexDoc.Event"), "Event")(p);
                memo[tuple(`Event`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Event(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(EventType, DO, FuncCall, SEMICOLON), "SlidexDoc.Event")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(EventType, DO, FuncCall, SEMICOLON), "SlidexDoc.Event"), "Event")(TParseTree("", false,[], s));
        }
    }
    static string Event(GetName g)
    {
        return "SlidexDoc.Event";
    }

    static TParseTree EventType(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(CLICKEVENT, TimerEvent), "SlidexDoc.EventType")(p);
        }
        else
        {
            if (auto m = tuple(`EventType`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(CLICKEVENT, TimerEvent), "SlidexDoc.EventType"), "EventType")(p);
                memo[tuple(`EventType`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree EventType(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(CLICKEVENT, TimerEvent), "SlidexDoc.EventType")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(CLICKEVENT, TimerEvent), "SlidexDoc.EventType"), "EventType")(TParseTree("", false,[], s));
        }
    }
    static string EventType(GetName g)
    {
        return "SlidexDoc.EventType";
    }

    static TParseTree TimerEvent(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(AFTER, Quantity), "SlidexDoc.TimerEvent")(p);
        }
        else
        {
            if (auto m = tuple(`TimerEvent`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(AFTER, Quantity), "SlidexDoc.TimerEvent"), "TimerEvent")(p);
                memo[tuple(`TimerEvent`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree TimerEvent(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(AFTER, Quantity), "SlidexDoc.TimerEvent")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(AFTER, Quantity), "SlidexDoc.TimerEvent"), "TimerEvent")(TParseTree("", false,[], s));
        }
    }
    static string TimerEvent(GetName g)
    {
        return "SlidexDoc.TimerEvent";
    }

    static TParseTree FuncCall(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Identifier, ArgList), "SlidexDoc.FuncCall")(p);
        }
        else
        {
            if (auto m = tuple(`FuncCall`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(Identifier, ArgList), "SlidexDoc.FuncCall"), "FuncCall")(p);
                memo[tuple(`FuncCall`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree FuncCall(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Identifier, ArgList), "SlidexDoc.FuncCall")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(Identifier, ArgList), "SlidexDoc.FuncCall"), "FuncCall")(TParseTree("", false,[], s));
        }
    }
    static string FuncCall(GetName g)
    {
        return "SlidexDoc.FuncCall";
    }

    static TParseTree ArgList(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(LPAREN, pegged.peg.option!(Args), RPAREN), "SlidexDoc.ArgList")(p);
        }
        else
        {
            if (auto m = tuple(`ArgList`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(LPAREN, pegged.peg.option!(Args), RPAREN), "SlidexDoc.ArgList"), "ArgList")(p);
                memo[tuple(`ArgList`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ArgList(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(LPAREN, pegged.peg.option!(Args), RPAREN), "SlidexDoc.ArgList")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(LPAREN, pegged.peg.option!(Args), RPAREN), "SlidexDoc.ArgList"), "ArgList")(TParseTree("", false,[], s));
        }
    }
    static string ArgList(GetName g)
    {
        return "SlidexDoc.ArgList";
    }

    static TParseTree Args(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Argument, pegged.peg.zeroOrMore!(pegged.peg.and!(COMMA, Argument)), pegged.peg.option!(COMMA)), "SlidexDoc.Args")(p);
        }
        else
        {
            if (auto m = tuple(`Args`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(Argument, pegged.peg.zeroOrMore!(pegged.peg.and!(COMMA, Argument)), pegged.peg.option!(COMMA)), "SlidexDoc.Args"), "Args")(p);
                memo[tuple(`Args`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Args(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Argument, pegged.peg.zeroOrMore!(pegged.peg.and!(COMMA, Argument)), pegged.peg.option!(COMMA)), "SlidexDoc.Args")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(Argument, pegged.peg.zeroOrMore!(pegged.peg.and!(COMMA, Argument)), pegged.peg.option!(COMMA)), "SlidexDoc.Args"), "Args")(TParseTree("", false,[], s));
        }
    }
    static string Args(GetName g)
    {
        return "SlidexDoc.Args";
    }

    static TParseTree Argument(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(NamedArg, PositionalArg), "SlidexDoc.Argument")(p);
        }
        else
        {
            if (auto m = tuple(`Argument`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(NamedArg, PositionalArg), "SlidexDoc.Argument"), "Argument")(p);
                memo[tuple(`Argument`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Argument(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(NamedArg, PositionalArg), "SlidexDoc.Argument")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(NamedArg, PositionalArg), "SlidexDoc.Argument"), "Argument")(TParseTree("", false,[], s));
        }
    }
    static string Argument(GetName g)
    {
        return "SlidexDoc.Argument";
    }

    static TParseTree NamedArg(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Identifier, EQUAL, Value), "SlidexDoc.NamedArg")(p);
        }
        else
        {
            if (auto m = tuple(`NamedArg`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(Identifier, EQUAL, Value), "SlidexDoc.NamedArg"), "NamedArg")(p);
                memo[tuple(`NamedArg`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree NamedArg(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Identifier, EQUAL, Value), "SlidexDoc.NamedArg")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(Identifier, EQUAL, Value), "SlidexDoc.NamedArg"), "NamedArg")(TParseTree("", false,[], s));
        }
    }
    static string NamedArg(GetName g)
    {
        return "SlidexDoc.NamedArg";
    }

    static TParseTree PositionalArg(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(Value, "SlidexDoc.PositionalArg")(p);
        }
        else
        {
            if (auto m = tuple(`PositionalArg`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(Value, "SlidexDoc.PositionalArg"), "PositionalArg")(p);
                memo[tuple(`PositionalArg`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree PositionalArg(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(Value, "SlidexDoc.PositionalArg")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(Value, "SlidexDoc.PositionalArg"), "PositionalArg")(TParseTree("", false,[], s));
        }
    }
    static string PositionalArg(GetName g)
    {
        return "SlidexDoc.PositionalArg";
    }

    static TParseTree OpeningIdentifier(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(Identifier, "SlidexDoc.OpeningIdentifier")(p);
        }
        else
        {
            if (auto m = tuple(`OpeningIdentifier`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(Identifier, "SlidexDoc.OpeningIdentifier"), "OpeningIdentifier")(p);
                memo[tuple(`OpeningIdentifier`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree OpeningIdentifier(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(Identifier, "SlidexDoc.OpeningIdentifier")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(Identifier, "SlidexDoc.OpeningIdentifier"), "OpeningIdentifier")(TParseTree("", false,[], s));
        }
    }
    static string OpeningIdentifier(GetName g)
    {
        return "SlidexDoc.OpeningIdentifier";
    }

    static TParseTree ClosingIdentifier(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(Identifier, "SlidexDoc.ClosingIdentifier")(p);
        }
        else
        {
            if (auto m = tuple(`ClosingIdentifier`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(Identifier, "SlidexDoc.ClosingIdentifier"), "ClosingIdentifier")(p);
                memo[tuple(`ClosingIdentifier`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ClosingIdentifier(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(Identifier, "SlidexDoc.ClosingIdentifier")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(Identifier, "SlidexDoc.ClosingIdentifier"), "ClosingIdentifier")(TParseTree("", false,[], s));
        }
    }
    static string ClosingIdentifier(GetName g)
    {
        return "SlidexDoc.ClosingIdentifier";
    }

    static TParseTree MasterIdentifier(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(Identifier, "SlidexDoc.MasterIdentifier")(p);
        }
        else
        {
            if (auto m = tuple(`MasterIdentifier`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(Identifier, "SlidexDoc.MasterIdentifier"), "MasterIdentifier")(p);
                memo[tuple(`MasterIdentifier`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree MasterIdentifier(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(Identifier, "SlidexDoc.MasterIdentifier")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(Identifier, "SlidexDoc.MasterIdentifier"), "MasterIdentifier")(TParseTree("", false,[], s));
        }
    }
    static string MasterIdentifier(GetName g)
    {
        return "SlidexDoc.MasterIdentifier";
    }

    static TParseTree Value(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(String, Array, Date, Quantity, RichText, Boolean, NamedColour, Alignment, FuncCall, QualifiedIdentifier), "SlidexDoc.Value")(p);
        }
        else
        {
            if (auto m = tuple(`Value`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(String, Array, Date, Quantity, RichText, Boolean, NamedColour, Alignment, FuncCall, QualifiedIdentifier), "SlidexDoc.Value"), "Value")(p);
                memo[tuple(`Value`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Value(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(String, Array, Date, Quantity, RichText, Boolean, NamedColour, Alignment, FuncCall, QualifiedIdentifier), "SlidexDoc.Value")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(String, Array, Date, Quantity, RichText, Boolean, NamedColour, Alignment, FuncCall, QualifiedIdentifier), "SlidexDoc.Value"), "Value")(TParseTree("", false,[], s));
        }
    }
    static string Value(GetName g)
    {
        return "SlidexDoc.Value";
    }

    static TParseTree Array(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(LSQUARE, pegged.peg.option!(ArrayValues), RSQUARE), "SlidexDoc.Array")(p);
        }
        else
        {
            if (auto m = tuple(`Array`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(LSQUARE, pegged.peg.option!(ArrayValues), RSQUARE), "SlidexDoc.Array"), "Array")(p);
                memo[tuple(`Array`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Array(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(LSQUARE, pegged.peg.option!(ArrayValues), RSQUARE), "SlidexDoc.Array")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(LSQUARE, pegged.peg.option!(ArrayValues), RSQUARE), "SlidexDoc.Array"), "Array")(TParseTree("", false,[], s));
        }
    }
    static string Array(GetName g)
    {
        return "SlidexDoc.Array";
    }

    static TParseTree ArrayValues(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Value, pegged.peg.zeroOrMore!(pegged.peg.and!(COMMA, Value))), "SlidexDoc.ArrayValues")(p);
        }
        else
        {
            if (auto m = tuple(`ArrayValues`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(Value, pegged.peg.zeroOrMore!(pegged.peg.and!(COMMA, Value))), "SlidexDoc.ArrayValues"), "ArrayValues")(p);
                memo[tuple(`ArrayValues`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ArrayValues(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Value, pegged.peg.zeroOrMore!(pegged.peg.and!(COMMA, Value))), "SlidexDoc.ArrayValues")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(Value, pegged.peg.zeroOrMore!(pegged.peg.and!(COMMA, Value))), "SlidexDoc.ArrayValues"), "ArrayValues")(TParseTree("", false,[], s));
        }
    }
    static string ArrayValues(GetName g)
    {
        return "SlidexDoc.ArrayValues";
    }

    static TParseTree Date(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.charRange!('1', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("-"), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("-"), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), WsComment)), "SlidexDoc.Date")(p);
        }
        else
        {
            if (auto m = tuple(`Date`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.charRange!('1', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("-"), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("-"), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), WsComment)), "SlidexDoc.Date"), "Date")(p);
                memo[tuple(`Date`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Date(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.charRange!('1', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("-"), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("-"), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), WsComment)), "SlidexDoc.Date")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.charRange!('1', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("-"), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), pegged.peg.literal!("-"), pegged.peg.charRange!('0', '9'), pegged.peg.charRange!('0', '9'), WsComment)), "SlidexDoc.Date"), "Date")(TParseTree("", false,[], s));
        }
    }
    static string Date(GetName g)
    {
        return "SlidexDoc.Date";
    }

    static TParseTree Number(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.literal!("-")), Digits), "SlidexDoc.Number")(p);
        }
        else
        {
            if (auto m = tuple(`Number`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.literal!("-")), Digits), "SlidexDoc.Number"), "Number")(p);
                memo[tuple(`Number`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Number(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.literal!("-")), Digits), "SlidexDoc.Number")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(pegged.peg.literal!("-")), Digits), "SlidexDoc.Number"), "Number")(TParseTree("", false,[], s));
        }
    }
    static string Number(GetName g)
    {
        return "SlidexDoc.Number";
    }

    static TParseTree Quantity(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Number, pegged.peg.option!(Unit)), "SlidexDoc.Quantity")(p);
        }
        else
        {
            if (auto m = tuple(`Quantity`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(Number, pegged.peg.option!(Unit)), "SlidexDoc.Quantity"), "Quantity")(p);
                memo[tuple(`Quantity`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Quantity(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(Number, pegged.peg.option!(Unit)), "SlidexDoc.Quantity")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(Number, pegged.peg.option!(Unit)), "SlidexDoc.Quantity"), "Quantity")(TParseTree("", false,[], s));
        }
    }
    static string Quantity(GetName g)
    {
        return "SlidexDoc.Quantity";
    }

    static TParseTree Digits(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.charRange!('0', '9'), pegged.peg.zeroOrMore!(pegged.peg.charRange!('0', '9')), WsComment)), "SlidexDoc.Digits")(p);
        }
        else
        {
            if (auto m = tuple(`Digits`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.charRange!('0', '9'), pegged.peg.zeroOrMore!(pegged.peg.charRange!('0', '9')), WsComment)), "SlidexDoc.Digits"), "Digits")(p);
                memo[tuple(`Digits`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Digits(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.charRange!('0', '9'), pegged.peg.zeroOrMore!(pegged.peg.charRange!('0', '9')), WsComment)), "SlidexDoc.Digits")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.charRange!('0', '9'), pegged.peg.zeroOrMore!(pegged.peg.charRange!('0', '9')), WsComment)), "SlidexDoc.Digits"), "Digits")(TParseTree("", false,[], s));
        }
    }
    static string Digits(GetName g)
    {
        return "SlidexDoc.Digits";
    }

    static TParseTree Unit(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("s", "%", "cm", "fr", "px"), WsComment), "SlidexDoc.Unit")(p);
        }
        else
        {
            if (auto m = tuple(`Unit`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("s", "%", "cm", "fr", "px"), WsComment), "SlidexDoc.Unit"), "Unit")(p);
                memo[tuple(`Unit`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Unit(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("s", "%", "cm", "fr", "px"), WsComment), "SlidexDoc.Unit")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("s", "%", "cm", "fr", "px"), WsComment), "SlidexDoc.Unit"), "Unit")(TParseTree("", false,[], s));
        }
    }
    static string Unit(GetName g)
    {
        return "SlidexDoc.Unit";
    }

    static TParseTree String(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.any))), pegged.peg.discard!(doublequote), WsComment), "SlidexDoc.String")(p);
        }
        else
        {
            if (auto m = tuple(`String`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.any))), pegged.peg.discard!(doublequote), WsComment), "SlidexDoc.String"), "String")(p);
                memo[tuple(`String`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree String(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.any))), pegged.peg.discard!(doublequote), WsComment), "SlidexDoc.String")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.any))), pegged.peg.discard!(doublequote), WsComment), "SlidexDoc.String"), "String")(TParseTree("", false,[], s));
        }
    }
    static string String(GetName g)
    {
        return "SlidexDoc.String";
    }

    static TParseTree RichText(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(LBRACE), pegged.peg.discard!(pegged.peg.option!(pegged.peg.and!(pegged.peg.zeroOrMore!(space), eol))), pegged.peg.zeroOrMore!(RichTextNode), pegged.peg.discard!(RBRACE)), "SlidexDoc.RichText")(p);
        }
        else
        {
            if (auto m = tuple(`RichText`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(LBRACE), pegged.peg.discard!(pegged.peg.option!(pegged.peg.and!(pegged.peg.zeroOrMore!(space), eol))), pegged.peg.zeroOrMore!(RichTextNode), pegged.peg.discard!(RBRACE)), "SlidexDoc.RichText"), "RichText")(p);
                memo[tuple(`RichText`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree RichText(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(LBRACE), pegged.peg.discard!(pegged.peg.option!(pegged.peg.and!(pegged.peg.zeroOrMore!(space), eol))), pegged.peg.zeroOrMore!(RichTextNode), pegged.peg.discard!(RBRACE)), "SlidexDoc.RichText")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(LBRACE), pegged.peg.discard!(pegged.peg.option!(pegged.peg.and!(pegged.peg.zeroOrMore!(space), eol))), pegged.peg.zeroOrMore!(RichTextNode), pegged.peg.discard!(RBRACE)), "SlidexDoc.RichText"), "RichText")(TParseTree("", false,[], s));
        }
    }
    static string RichText(GetName g)
    {
        return "SlidexDoc.RichText";
    }

    static TParseTree NamedColour(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("red", "green", "blue", "yellow", "cyan", "magenta", "white", "black"), WsComment), "SlidexDoc.NamedColour")(p);
        }
        else
        {
            if (auto m = tuple(`NamedColour`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("red", "green", "blue", "yellow", "cyan", "magenta", "white", "black"), WsComment), "SlidexDoc.NamedColour"), "NamedColour")(p);
                memo[tuple(`NamedColour`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree NamedColour(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("red", "green", "blue", "yellow", "cyan", "magenta", "white", "black"), WsComment), "SlidexDoc.NamedColour")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("red", "green", "blue", "yellow", "cyan", "magenta", "white", "black"), WsComment), "SlidexDoc.NamedColour"), "NamedColour")(TParseTree("", false,[], s));
        }
    }
    static string NamedColour(GetName g)
    {
        return "SlidexDoc.NamedColour";
    }

    static TParseTree Alignment(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("topleft", "topcenter", "topright", "centerleft", "centerright", "center", "bottomleft", "bottomcenter", "bottomright"), WsComment), "SlidexDoc.Alignment")(p);
        }
        else
        {
            if (auto m = tuple(`Alignment`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("topleft", "topcenter", "topright", "centerleft", "centerright", "center", "bottomleft", "bottomcenter", "bottomright"), WsComment), "SlidexDoc.Alignment"), "Alignment")(p);
                memo[tuple(`Alignment`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Alignment(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("topleft", "topcenter", "topright", "centerleft", "centerright", "center", "bottomleft", "bottomcenter", "bottomright"), WsComment), "SlidexDoc.Alignment")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("topleft", "topcenter", "topright", "centerleft", "centerright", "center", "bottomleft", "bottomcenter", "bottomright"), WsComment), "SlidexDoc.Alignment"), "Alignment")(TParseTree("", false,[], s));
        }
    }
    static string Alignment(GetName g)
    {
        return "SlidexDoc.Alignment";
    }

    static TParseTree Boolean(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("true", "false", "yes", "no", "on", "off"), WsComment), "SlidexDoc.Boolean")(p);
        }
        else
        {
            if (auto m = tuple(`Boolean`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("true", "false", "yes", "no", "on", "off"), WsComment), "SlidexDoc.Boolean"), "Boolean")(p);
                memo[tuple(`Boolean`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Boolean(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("true", "false", "yes", "no", "on", "off"), WsComment), "SlidexDoc.Boolean")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.keywords!("true", "false", "yes", "no", "on", "off"), WsComment), "SlidexDoc.Boolean"), "Boolean")(TParseTree("", false,[], s));
        }
    }
    static string Boolean(GetName g)
    {
        return "SlidexDoc.Boolean";
    }

    static TParseTree Identifier(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(identifier, WsComment), "SlidexDoc.Identifier")(p);
        }
        else
        {
            if (auto m = tuple(`Identifier`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(identifier, WsComment), "SlidexDoc.Identifier"), "Identifier")(p);
                memo[tuple(`Identifier`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Identifier(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(identifier, WsComment), "SlidexDoc.Identifier")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(identifier, WsComment), "SlidexDoc.Identifier"), "Identifier")(TParseTree("", false,[], s));
        }
    }
    static string Identifier(GetName g)
    {
        return "SlidexDoc.Identifier";
    }

    static TParseTree QualifiedIdentifier(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(identifier, pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.literal!("."), identifier)), WsComment), "SlidexDoc.QualifiedIdentifier")(p);
        }
        else
        {
            if (auto m = tuple(`QualifiedIdentifier`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(identifier, pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.literal!("."), identifier)), WsComment), "SlidexDoc.QualifiedIdentifier"), "QualifiedIdentifier")(p);
                memo[tuple(`QualifiedIdentifier`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree QualifiedIdentifier(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(identifier, pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.literal!("."), identifier)), WsComment), "SlidexDoc.QualifiedIdentifier")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(identifier, pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.literal!("."), identifier)), WsComment), "SlidexDoc.QualifiedIdentifier"), "QualifiedIdentifier")(TParseTree("", false,[], s));
        }
    }
    static string QualifiedIdentifier(GetName g)
    {
        return "SlidexDoc.QualifiedIdentifier";
    }

    static TParseTree DECK(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("deck"), WsComment), "SlidexDoc.DECK")(p);
        }
        else
        {
            if (auto m = tuple(`DECK`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("deck"), WsComment), "SlidexDoc.DECK"), "DECK")(p);
                memo[tuple(`DECK`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree DECK(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("deck"), WsComment), "SlidexDoc.DECK")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("deck"), WsComment), "SlidexDoc.DECK"), "DECK")(TParseTree("", false,[], s));
        }
    }
    static string DECK(GetName g)
    {
        return "SlidexDoc.DECK";
    }

    static TParseTree MASTER(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("master"), WsComment), "SlidexDoc.MASTER")(p);
        }
        else
        {
            if (auto m = tuple(`MASTER`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("master"), WsComment), "SlidexDoc.MASTER"), "MASTER")(p);
                memo[tuple(`MASTER`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree MASTER(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("master"), WsComment), "SlidexDoc.MASTER")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("master"), WsComment), "SlidexDoc.MASTER"), "MASTER")(TParseTree("", false,[], s));
        }
    }
    static string MASTER(GetName g)
    {
        return "SlidexDoc.MASTER";
    }

    static TParseTree SLIDE(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("slide"), WsComment), "SlidexDoc.SLIDE")(p);
        }
        else
        {
            if (auto m = tuple(`SLIDE`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("slide"), WsComment), "SlidexDoc.SLIDE"), "SLIDE")(p);
                memo[tuple(`SLIDE`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree SLIDE(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("slide"), WsComment), "SlidexDoc.SLIDE")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("slide"), WsComment), "SlidexDoc.SLIDE"), "SLIDE")(TParseTree("", false,[], s));
        }
    }
    static string SLIDE(GetName g)
    {
        return "SlidexDoc.SLIDE";
    }

    static TParseTree FROM(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("from"), WsComment), "SlidexDoc.FROM")(p);
        }
        else
        {
            if (auto m = tuple(`FROM`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("from"), WsComment), "SlidexDoc.FROM"), "FROM")(p);
                memo[tuple(`FROM`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree FROM(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("from"), WsComment), "SlidexDoc.FROM")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("from"), WsComment), "SlidexDoc.FROM"), "FROM")(TParseTree("", false,[], s));
        }
    }
    static string FROM(GetName g)
    {
        return "SlidexDoc.FROM";
    }

    static TParseTree BEGIN(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("begin"), WsComment), "SlidexDoc.BEGIN")(p);
        }
        else
        {
            if (auto m = tuple(`BEGIN`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("begin"), WsComment), "SlidexDoc.BEGIN"), "BEGIN")(p);
                memo[tuple(`BEGIN`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree BEGIN(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("begin"), WsComment), "SlidexDoc.BEGIN")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("begin"), WsComment), "SlidexDoc.BEGIN"), "BEGIN")(TParseTree("", false,[], s));
        }
    }
    static string BEGIN(GetName g)
    {
        return "SlidexDoc.BEGIN";
    }

    static TParseTree END(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("end"), WsComment), "SlidexDoc.END")(p);
        }
        else
        {
            if (auto m = tuple(`END`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("end"), WsComment), "SlidexDoc.END"), "END")(p);
                memo[tuple(`END`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree END(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("end"), WsComment), "SlidexDoc.END")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("end"), WsComment), "SlidexDoc.END"), "END")(TParseTree("", false,[], s));
        }
    }
    static string END(GetName g)
    {
        return "SlidexDoc.END";
    }

    static TParseTree SEQUENCE(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("sequence"), WsComment), "SlidexDoc.SEQUENCE")(p);
        }
        else
        {
            if (auto m = tuple(`SEQUENCE`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("sequence"), WsComment), "SlidexDoc.SEQUENCE"), "SEQUENCE")(p);
                memo[tuple(`SEQUENCE`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree SEQUENCE(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("sequence"), WsComment), "SlidexDoc.SEQUENCE")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("sequence"), WsComment), "SlidexDoc.SEQUENCE"), "SEQUENCE")(TParseTree("", false,[], s));
        }
    }
    static string SEQUENCE(GetName g)
    {
        return "SlidexDoc.SEQUENCE";
    }

    static TParseTree DO(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("do"), WsComment), "SlidexDoc.DO")(p);
        }
        else
        {
            if (auto m = tuple(`DO`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("do"), WsComment), "SlidexDoc.DO"), "DO")(p);
                memo[tuple(`DO`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree DO(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("do"), WsComment), "SlidexDoc.DO")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("do"), WsComment), "SlidexDoc.DO"), "DO")(TParseTree("", false,[], s));
        }
    }
    static string DO(GetName g)
    {
        return "SlidexDoc.DO";
    }

    static TParseTree CLICKEVENT(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("on"), WsComment, pegged.peg.literal!("click"), WsComment), "SlidexDoc.CLICKEVENT")(p);
        }
        else
        {
            if (auto m = tuple(`CLICKEVENT`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("on"), WsComment, pegged.peg.literal!("click"), WsComment), "SlidexDoc.CLICKEVENT"), "CLICKEVENT")(p);
                memo[tuple(`CLICKEVENT`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree CLICKEVENT(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("on"), WsComment, pegged.peg.literal!("click"), WsComment), "SlidexDoc.CLICKEVENT")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("on"), WsComment, pegged.peg.literal!("click"), WsComment), "SlidexDoc.CLICKEVENT"), "CLICKEVENT")(TParseTree("", false,[], s));
        }
    }
    static string CLICKEVENT(GetName g)
    {
        return "SlidexDoc.CLICKEVENT";
    }

    static TParseTree AFTER(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("after"), WsComment), "SlidexDoc.AFTER")(p);
        }
        else
        {
            if (auto m = tuple(`AFTER`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("after"), WsComment), "SlidexDoc.AFTER"), "AFTER")(p);
                memo[tuple(`AFTER`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree AFTER(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("after"), WsComment), "SlidexDoc.AFTER")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("after"), WsComment), "SlidexDoc.AFTER"), "AFTER")(TParseTree("", false,[], s));
        }
    }
    static string AFTER(GetName g)
    {
        return "SlidexDoc.AFTER";
    }

    static TParseTree AT(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("at"), WsComment), "SlidexDoc.AT")(p);
        }
        else
        {
            if (auto m = tuple(`AT`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("at"), WsComment), "SlidexDoc.AT"), "AT")(p);
                memo[tuple(`AT`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree AT(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("at"), WsComment), "SlidexDoc.AT")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("at"), WsComment), "SlidexDoc.AT"), "AT")(TParseTree("", false,[], s));
        }
    }
    static string AT(GetName g)
    {
        return "SlidexDoc.AT";
    }

    static TParseTree CELL(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("cell"), WsComment), "SlidexDoc.CELL")(p);
        }
        else
        {
            if (auto m = tuple(`CELL`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("cell"), WsComment), "SlidexDoc.CELL"), "CELL")(p);
                memo[tuple(`CELL`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree CELL(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("cell"), WsComment), "SlidexDoc.CELL")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("cell"), WsComment), "SlidexDoc.CELL"), "CELL")(TParseTree("", false,[], s));
        }
    }
    static string CELL(GetName g)
    {
        return "SlidexDoc.CELL";
    }

    static TParseTree BOUNDS(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("bounds"), WsComment), "SlidexDoc.BOUNDS")(p);
        }
        else
        {
            if (auto m = tuple(`BOUNDS`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("bounds"), WsComment), "SlidexDoc.BOUNDS"), "BOUNDS")(p);
                memo[tuple(`BOUNDS`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree BOUNDS(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("bounds"), WsComment), "SlidexDoc.BOUNDS")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("bounds"), WsComment), "SlidexDoc.BOUNDS"), "BOUNDS")(TParseTree("", false,[], s));
        }
    }
    static string BOUNDS(GetName g)
    {
        return "SlidexDoc.BOUNDS";
    }

    static TParseTree LPAREN(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("("), WsComment), "SlidexDoc.LPAREN")(p);
        }
        else
        {
            if (auto m = tuple(`LPAREN`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("("), WsComment), "SlidexDoc.LPAREN"), "LPAREN")(p);
                memo[tuple(`LPAREN`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree LPAREN(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("("), WsComment), "SlidexDoc.LPAREN")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("("), WsComment), "SlidexDoc.LPAREN"), "LPAREN")(TParseTree("", false,[], s));
        }
    }
    static string LPAREN(GetName g)
    {
        return "SlidexDoc.LPAREN";
    }

    static TParseTree RPAREN(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(")"), WsComment), "SlidexDoc.RPAREN")(p);
        }
        else
        {
            if (auto m = tuple(`RPAREN`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(")"), WsComment), "SlidexDoc.RPAREN"), "RPAREN")(p);
                memo[tuple(`RPAREN`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree RPAREN(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(")"), WsComment), "SlidexDoc.RPAREN")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(")"), WsComment), "SlidexDoc.RPAREN"), "RPAREN")(TParseTree("", false,[], s));
        }
    }
    static string RPAREN(GetName g)
    {
        return "SlidexDoc.RPAREN";
    }

    static TParseTree LSQUARE(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), WsComment), "SlidexDoc.LSQUARE")(p);
        }
        else
        {
            if (auto m = tuple(`LSQUARE`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), WsComment), "SlidexDoc.LSQUARE"), "LSQUARE")(p);
                memo[tuple(`LSQUARE`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree LSQUARE(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), WsComment), "SlidexDoc.LSQUARE")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), WsComment), "SlidexDoc.LSQUARE"), "LSQUARE")(TParseTree("", false,[], s));
        }
    }
    static string LSQUARE(GetName g)
    {
        return "SlidexDoc.LSQUARE";
    }

    static TParseTree RSQUARE(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("]"), WsComment), "SlidexDoc.RSQUARE")(p);
        }
        else
        {
            if (auto m = tuple(`RSQUARE`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("]"), WsComment), "SlidexDoc.RSQUARE"), "RSQUARE")(p);
                memo[tuple(`RSQUARE`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree RSQUARE(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("]"), WsComment), "SlidexDoc.RSQUARE")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("]"), WsComment), "SlidexDoc.RSQUARE"), "RSQUARE")(TParseTree("", false,[], s));
        }
    }
    static string RSQUARE(GetName g)
    {
        return "SlidexDoc.RSQUARE";
    }

    static TParseTree LBRACE(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("{"), "SlidexDoc.LBRACE")(p);
        }
        else
        {
            if (auto m = tuple(`LBRACE`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.literal!("{"), "SlidexDoc.LBRACE"), "LBRACE")(p);
                memo[tuple(`LBRACE`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree LBRACE(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.literal!("{"), "SlidexDoc.LBRACE")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.literal!("{"), "SlidexDoc.LBRACE"), "LBRACE")(TParseTree("", false,[], s));
        }
    }
    static string LBRACE(GetName g)
    {
        return "SlidexDoc.LBRACE";
    }

    static TParseTree RBRACE(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("}"), WsComment), "SlidexDoc.RBRACE")(p);
        }
        else
        {
            if (auto m = tuple(`RBRACE`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("}"), WsComment), "SlidexDoc.RBRACE"), "RBRACE")(p);
                memo[tuple(`RBRACE`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree RBRACE(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("}"), WsComment), "SlidexDoc.RBRACE")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("}"), WsComment), "SlidexDoc.RBRACE"), "RBRACE")(TParseTree("", false,[], s));
        }
    }
    static string RBRACE(GetName g)
    {
        return "SlidexDoc.RBRACE";
    }

    static TParseTree SEMICOLON(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.discard!(pegged.peg.and!(pegged.peg.literal!(";"), WsComment)), "SlidexDoc.SEMICOLON")(p);
        }
        else
        {
            if (auto m = tuple(`SEMICOLON`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.discard!(pegged.peg.and!(pegged.peg.literal!(";"), WsComment)), "SlidexDoc.SEMICOLON"), "SEMICOLON")(p);
                memo[tuple(`SEMICOLON`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree SEMICOLON(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.discard!(pegged.peg.and!(pegged.peg.literal!(";"), WsComment)), "SlidexDoc.SEMICOLON")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.discard!(pegged.peg.and!(pegged.peg.literal!(";"), WsComment)), "SlidexDoc.SEMICOLON"), "SEMICOLON")(TParseTree("", false,[], s));
        }
    }
    static string SEMICOLON(GetName g)
    {
        return "SlidexDoc.SEMICOLON";
    }

    static TParseTree CREATE(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(":="), WsComment), "SlidexDoc.CREATE")(p);
        }
        else
        {
            if (auto m = tuple(`CREATE`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(":="), WsComment), "SlidexDoc.CREATE"), "CREATE")(p);
                memo[tuple(`CREATE`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree CREATE(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(":="), WsComment), "SlidexDoc.CREATE")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(":="), WsComment), "SlidexDoc.CREATE"), "CREATE")(TParseTree("", false,[], s));
        }
    }
    static string CREATE(GetName g)
    {
        return "SlidexDoc.CREATE";
    }

    static TParseTree EQUAL(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("="), WsComment), "SlidexDoc.EQUAL")(p);
        }
        else
        {
            if (auto m = tuple(`EQUAL`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("="), WsComment), "SlidexDoc.EQUAL"), "EQUAL")(p);
                memo[tuple(`EQUAL`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree EQUAL(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("="), WsComment), "SlidexDoc.EQUAL")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("="), WsComment), "SlidexDoc.EQUAL"), "EQUAL")(TParseTree("", false,[], s));
        }
    }
    static string EQUAL(GetName g)
    {
        return "SlidexDoc.EQUAL";
    }

    static TParseTree COMMA(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(","), WsComment), "SlidexDoc.COMMA")(p);
        }
        else
        {
            if (auto m = tuple(`COMMA`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(","), WsComment), "SlidexDoc.COMMA"), "COMMA")(p);
                memo[tuple(`COMMA`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree COMMA(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(","), WsComment), "SlidexDoc.COMMA")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!(","), WsComment), "SlidexDoc.COMMA"), "COMMA")(TParseTree("", false,[], s));
        }
    }
    static string COMMA(GetName g)
    {
        return "SlidexDoc.COMMA";
    }

    static TParseTree WsComment(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(pegged.peg.or!(InlineComment, EolComment, pegged.peg.discard!(blank))), "SlidexDoc.WsComment")(p);
        }
        else
        {
            if (auto m = tuple(`WsComment`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(pegged.peg.or!(InlineComment, EolComment, pegged.peg.discard!(blank))), "SlidexDoc.WsComment"), "WsComment")(p);
                memo[tuple(`WsComment`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree WsComment(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(pegged.peg.or!(InlineComment, EolComment, pegged.peg.discard!(blank))), "SlidexDoc.WsComment")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(pegged.peg.or!(InlineComment, EolComment, pegged.peg.discard!(blank))), "SlidexDoc.WsComment"), "WsComment")(TParseTree("", false,[], s));
        }
    }
    static string WsComment(GetName g)
    {
        return "SlidexDoc.WsComment";
    }

    static TParseTree EolComment(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("#"), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(eol), pegged.peg.any))), pegged.peg.discard!(eol)), "SlidexDoc.EolComment")(p);
        }
        else
        {
            if (auto m = tuple(`EolComment`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("#"), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(eol), pegged.peg.any))), pegged.peg.discard!(eol)), "SlidexDoc.EolComment"), "EolComment")(p);
                memo[tuple(`EolComment`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree EolComment(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("#"), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(eol), pegged.peg.any))), pegged.peg.discard!(eol)), "SlidexDoc.EolComment")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("#"), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(eol), pegged.peg.any))), pegged.peg.discard!(eol)), "SlidexDoc.EolComment"), "EolComment")(TParseTree("", false,[], s));
        }
    }
    static string EolComment(GetName g)
    {
        return "SlidexDoc.EolComment";
    }

    static TParseTree InlineComment(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("/#"), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(pegged.peg.literal!("#/")), pegged.peg.any))), pegged.peg.literal!("#/")), "SlidexDoc.InlineComment")(p);
        }
        else
        {
            if (auto m = tuple(`InlineComment`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("/#"), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(pegged.peg.literal!("#/")), pegged.peg.any))), pegged.peg.literal!("#/")), "SlidexDoc.InlineComment"), "InlineComment")(p);
                memo[tuple(`InlineComment`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree InlineComment(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("/#"), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(pegged.peg.literal!("#/")), pegged.peg.any))), pegged.peg.literal!("#/")), "SlidexDoc.InlineComment")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("/#"), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(pegged.peg.literal!("#/")), pegged.peg.any))), pegged.peg.literal!("#/")), "SlidexDoc.InlineComment"), "InlineComment")(TParseTree("", false,[], s));
        }
    }
    static string InlineComment(GetName g)
    {
        return "SlidexDoc.InlineComment";
    }

    static TParseTree RichTextNode(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(LineBreak, EscapedChar, CodeBlock, ListBlock, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, Word, pegged.peg.discard!(space)), "SlidexDoc.RichTextNode")(p);
        }
        else
        {
            if (auto m = tuple(`RichTextNode`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(LineBreak, EscapedChar, CodeBlock, ListBlock, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, Word, pegged.peg.discard!(space)), "SlidexDoc.RichTextNode"), "RichTextNode")(p);
                memo[tuple(`RichTextNode`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree RichTextNode(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(LineBreak, EscapedChar, CodeBlock, ListBlock, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, Word, pegged.peg.discard!(space)), "SlidexDoc.RichTextNode")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(LineBreak, EscapedChar, CodeBlock, ListBlock, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, Word, pegged.peg.discard!(space)), "SlidexDoc.RichTextNode"), "RichTextNode")(TParseTree("", false,[], s));
        }
    }
    static string RichTextNode(GetName g)
    {
        return "SlidexDoc.RichTextNode";
    }

    static TParseTree Bold(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("*"), InlineContent, pegged.peg.literal!("*")), "SlidexDoc.Bold")(p);
        }
        else
        {
            if (auto m = tuple(`Bold`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("*"), InlineContent, pegged.peg.literal!("*")), "SlidexDoc.Bold"), "Bold")(p);
                memo[tuple(`Bold`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Bold(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("*"), InlineContent, pegged.peg.literal!("*")), "SlidexDoc.Bold")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("*"), InlineContent, pegged.peg.literal!("*")), "SlidexDoc.Bold"), "Bold")(TParseTree("", false,[], s));
        }
    }
    static string Bold(GetName g)
    {
        return "SlidexDoc.Bold";
    }

    static TParseTree Italic(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("/"), InlineContent, pegged.peg.literal!("/")), "SlidexDoc.Italic")(p);
        }
        else
        {
            if (auto m = tuple(`Italic`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("/"), InlineContent, pegged.peg.literal!("/")), "SlidexDoc.Italic"), "Italic")(p);
                memo[tuple(`Italic`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Italic(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("/"), InlineContent, pegged.peg.literal!("/")), "SlidexDoc.Italic")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("/"), InlineContent, pegged.peg.literal!("/")), "SlidexDoc.Italic"), "Italic")(TParseTree("", false,[], s));
        }
    }
    static string Italic(GetName g)
    {
        return "SlidexDoc.Italic";
    }

    static TParseTree Underline(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("_"), InlineContent, pegged.peg.literal!("_")), "SlidexDoc.Underline")(p);
        }
        else
        {
            if (auto m = tuple(`Underline`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("_"), InlineContent, pegged.peg.literal!("_")), "SlidexDoc.Underline"), "Underline")(p);
                memo[tuple(`Underline`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Underline(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("_"), InlineContent, pegged.peg.literal!("_")), "SlidexDoc.Underline")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("_"), InlineContent, pegged.peg.literal!("_")), "SlidexDoc.Underline"), "Underline")(TParseTree("", false,[], s));
        }
    }
    static string Underline(GetName g)
    {
        return "SlidexDoc.Underline";
    }

    static TParseTree Strike(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("~"), InlineContent, pegged.peg.literal!("~")), "SlidexDoc.Strike")(p);
        }
        else
        {
            if (auto m = tuple(`Strike`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("~"), InlineContent, pegged.peg.literal!("~")), "SlidexDoc.Strike"), "Strike")(p);
                memo[tuple(`Strike`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Strike(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("~"), InlineContent, pegged.peg.literal!("~")), "SlidexDoc.Strike")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("~"), InlineContent, pegged.peg.literal!("~")), "SlidexDoc.Strike"), "Strike")(TParseTree("", false,[], s));
        }
    }
    static string Strike(GetName g)
    {
        return "SlidexDoc.Strike";
    }

    static TParseTree SmallCaps(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("#"), InlineContent, pegged.peg.literal!("#")), "SlidexDoc.SmallCaps")(p);
        }
        else
        {
            if (auto m = tuple(`SmallCaps`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("#"), InlineContent, pegged.peg.literal!("#")), "SlidexDoc.SmallCaps"), "SmallCaps")(p);
                memo[tuple(`SmallCaps`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree SmallCaps(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("#"), InlineContent, pegged.peg.literal!("#")), "SlidexDoc.SmallCaps")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("#"), InlineContent, pegged.peg.literal!("#")), "SlidexDoc.SmallCaps"), "SmallCaps")(TParseTree("", false,[], s));
        }
    }
    static string SmallCaps(GetName g)
    {
        return "SlidexDoc.SmallCaps";
    }

    static TParseTree Variable(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("$"), identifier), "SlidexDoc.Variable")(p);
        }
        else
        {
            if (auto m = tuple(`Variable`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("$"), identifier), "SlidexDoc.Variable"), "Variable")(p);
                memo[tuple(`Variable`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Variable(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("$"), identifier), "SlidexDoc.Variable")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("$"), identifier), "SlidexDoc.Variable"), "Variable")(TParseTree("", false,[], s));
        }
    }
    static string Variable(GetName g)
    {
        return "SlidexDoc.Variable";
    }

    static TParseTree Func(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), WS, FuncName, WS, FuncArgs, WS, pegged.peg.option!(pegged.peg.and!(pegged.peg.literal!(":"), WS, InlineContent)), pegged.peg.literal!("]")), "SlidexDoc.Func")(p);
        }
        else
        {
            if (auto m = tuple(`Func`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), WS, FuncName, WS, FuncArgs, WS, pegged.peg.option!(pegged.peg.and!(pegged.peg.literal!(":"), WS, InlineContent)), pegged.peg.literal!("]")), "SlidexDoc.Func"), "Func")(p);
                memo[tuple(`Func`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Func(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), WS, FuncName, WS, FuncArgs, WS, pegged.peg.option!(pegged.peg.and!(pegged.peg.literal!(":"), WS, InlineContent)), pegged.peg.literal!("]")), "SlidexDoc.Func")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("["), WS, FuncName, WS, FuncArgs, WS, pegged.peg.option!(pegged.peg.and!(pegged.peg.literal!(":"), WS, InlineContent)), pegged.peg.literal!("]")), "SlidexDoc.Func"), "Func")(TParseTree("", false,[], s));
        }
    }
    static string Func(GetName g)
    {
        return "SlidexDoc.Func";
    }

    static TParseTree FuncName(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(identifier, "SlidexDoc.FuncName")(p);
        }
        else
        {
            if (auto m = tuple(`FuncName`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(identifier, "SlidexDoc.FuncName"), "FuncName")(p);
                memo[tuple(`FuncName`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree FuncName(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(identifier, "SlidexDoc.FuncName")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(identifier, "SlidexDoc.FuncName"), "FuncName")(TParseTree("", false,[], s));
        }
    }
    static string FuncName(GetName g)
    {
        return "SlidexDoc.FuncName";
    }

    static TParseTree FuncArgs(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(FuncArg), pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.literal!(","), FuncArg))), "SlidexDoc.FuncArgs")(p);
        }
        else
        {
            if (auto m = tuple(`FuncArgs`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(FuncArg), pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.literal!(","), FuncArg))), "SlidexDoc.FuncArgs"), "FuncArgs")(p);
                memo[tuple(`FuncArgs`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree FuncArgs(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(FuncArg), pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.literal!(","), FuncArg))), "SlidexDoc.FuncArgs")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.option!(FuncArg), pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.literal!(","), FuncArg))), "SlidexDoc.FuncArgs"), "FuncArgs")(TParseTree("", false,[], s));
        }
    }
    static string FuncArgs(GetName g)
    {
        return "SlidexDoc.FuncArgs";
    }

    static TParseTree FuncArg(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(RTString, RTNumber, identifier), "SlidexDoc.FuncArg")(p);
        }
        else
        {
            if (auto m = tuple(`FuncArg`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(RTString, RTNumber, identifier), "SlidexDoc.FuncArg"), "FuncArg")(p);
                memo[tuple(`FuncArg`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree FuncArg(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(RTString, RTNumber, identifier), "SlidexDoc.FuncArg")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(RTString, RTNumber, identifier), "SlidexDoc.FuncArg"), "FuncArg")(TParseTree("", false,[], s));
        }
    }
    static string FuncArg(GetName g)
    {
        return "SlidexDoc.FuncArg";
    }

    static TParseTree InlineContent(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(InlineNode), "SlidexDoc.InlineContent")(p);
        }
        else
        {
            if (auto m = tuple(`InlineContent`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(InlineNode), "SlidexDoc.InlineContent"), "InlineContent")(p);
                memo[tuple(`InlineContent`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree InlineContent(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(InlineNode), "SlidexDoc.InlineContent")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(InlineNode), "SlidexDoc.InlineContent"), "InlineContent")(TParseTree("", false,[], s));
        }
    }
    static string InlineContent(GetName g)
    {
        return "SlidexDoc.InlineContent";
    }

    static TParseTree InlineNode(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(LineBreak, EscapedChar, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, InlineWord, pegged.peg.discard!(space)), "SlidexDoc.InlineNode")(p);
        }
        else
        {
            if (auto m = tuple(`InlineNode`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(LineBreak, EscapedChar, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, InlineWord, pegged.peg.discard!(space)), "SlidexDoc.InlineNode"), "InlineNode")(p);
                memo[tuple(`InlineNode`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree InlineNode(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(LineBreak, EscapedChar, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, InlineWord, pegged.peg.discard!(space)), "SlidexDoc.InlineNode")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(LineBreak, EscapedChar, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, InlineWord, pegged.peg.discard!(space)), "SlidexDoc.InlineNode"), "InlineNode")(TParseTree("", false,[], s));
        }
    }
    static string InlineNode(GetName g)
    {
        return "SlidexDoc.InlineNode";
    }

    static TParseTree ListItemContent(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(ListItemNode), "SlidexDoc.ListItemContent")(p);
        }
        else
        {
            if (auto m = tuple(`ListItemContent`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(ListItemNode), "SlidexDoc.ListItemContent"), "ListItemContent")(p);
                memo[tuple(`ListItemContent`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ListItemContent(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.zeroOrMore!(ListItemNode), "SlidexDoc.ListItemContent")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.zeroOrMore!(ListItemNode), "SlidexDoc.ListItemContent"), "ListItemContent")(TParseTree("", false,[], s));
        }
    }
    static string ListItemContent(GetName g)
    {
        return "SlidexDoc.ListItemContent";
    }

    static TParseTree ListItemNode(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(EscapedChar, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, InlineWord, pegged.peg.discard!(space)), "SlidexDoc.ListItemNode")(p);
        }
        else
        {
            if (auto m = tuple(`ListItemNode`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(EscapedChar, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, InlineWord, pegged.peg.discard!(space)), "SlidexDoc.ListItemNode"), "ListItemNode")(p);
                memo[tuple(`ListItemNode`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ListItemNode(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(EscapedChar, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, InlineWord, pegged.peg.discard!(space)), "SlidexDoc.ListItemNode")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(EscapedChar, Func, Bold, Italic, Underline, Strike, SmallCaps, Variable, InlineWord, pegged.peg.discard!(space)), "SlidexDoc.ListItemNode"), "ListItemNode")(TParseTree("", false,[], s));
        }
    }
    static string ListItemNode(GetName g)
    {
        return "SlidexDoc.ListItemNode";
    }

    static TParseTree ListBlock(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.oneOrMore!(ListItem), "SlidexDoc.ListBlock")(p);
        }
        else
        {
            if (auto m = tuple(`ListBlock`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.oneOrMore!(ListItem), "SlidexDoc.ListBlock"), "ListBlock")(p);
                memo[tuple(`ListBlock`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ListBlock(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.oneOrMore!(ListItem), "SlidexDoc.ListBlock")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.oneOrMore!(ListItem), "SlidexDoc.ListBlock"), "ListBlock")(TParseTree("", false,[], s));
        }
    }
    static string ListBlock(GetName g)
    {
        return "SlidexDoc.ListBlock";
    }

    static TParseTree ListItem(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(BulletMarker, NumberMarker), ListItemContent, eol), "SlidexDoc.ListItem")(p);
        }
        else
        {
            if (auto m = tuple(`ListItem`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(BulletMarker, NumberMarker), ListItemContent, eol), "SlidexDoc.ListItem"), "ListItem")(p);
                memo[tuple(`ListItem`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree ListItem(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(BulletMarker, NumberMarker), ListItemContent, eol), "SlidexDoc.ListItem")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.or!(BulletMarker, NumberMarker), ListItemContent, eol), "SlidexDoc.ListItem"), "ListItem")(TParseTree("", false,[], s));
        }
    }
    static string ListItem(GetName g)
    {
        return "SlidexDoc.ListItem";
    }

    static TParseTree BulletMarker(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.literal!(" ")), pegged.peg.literal!("-"), pegged.peg.oneOrMore!(pegged.peg.literal!(" "))), "SlidexDoc.BulletMarker")(p);
        }
        else
        {
            if (auto m = tuple(`BulletMarker`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.literal!(" ")), pegged.peg.literal!("-"), pegged.peg.oneOrMore!(pegged.peg.literal!(" "))), "SlidexDoc.BulletMarker"), "BulletMarker")(p);
                memo[tuple(`BulletMarker`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree BulletMarker(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.literal!(" ")), pegged.peg.literal!("-"), pegged.peg.oneOrMore!(pegged.peg.literal!(" "))), "SlidexDoc.BulletMarker")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.literal!(" ")), pegged.peg.literal!("-"), pegged.peg.oneOrMore!(pegged.peg.literal!(" "))), "SlidexDoc.BulletMarker"), "BulletMarker")(TParseTree("", false,[], s));
        }
    }
    static string BulletMarker(GetName g)
    {
        return "SlidexDoc.BulletMarker";
    }

    static TParseTree NumberMarker(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.literal!(" ")), pegged.peg.oneOrMore!(pegged.peg.charRange!('0', '9')), pegged.peg.literal!("."), pegged.peg.oneOrMore!(pegged.peg.literal!(" "))), "SlidexDoc.NumberMarker")(p);
        }
        else
        {
            if (auto m = tuple(`NumberMarker`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.literal!(" ")), pegged.peg.oneOrMore!(pegged.peg.charRange!('0', '9')), pegged.peg.literal!("."), pegged.peg.oneOrMore!(pegged.peg.literal!(" "))), "SlidexDoc.NumberMarker"), "NumberMarker")(p);
                memo[tuple(`NumberMarker`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree NumberMarker(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.literal!(" ")), pegged.peg.oneOrMore!(pegged.peg.charRange!('0', '9')), pegged.peg.literal!("."), pegged.peg.oneOrMore!(pegged.peg.literal!(" "))), "SlidexDoc.NumberMarker")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.literal!(" ")), pegged.peg.oneOrMore!(pegged.peg.charRange!('0', '9')), pegged.peg.literal!("."), pegged.peg.oneOrMore!(pegged.peg.literal!(" "))), "SlidexDoc.NumberMarker"), "NumberMarker")(TParseTree("", false,[], s));
        }
    }
    static string NumberMarker(GetName g)
    {
        return "SlidexDoc.NumberMarker";
    }

    static TParseTree CodeBlock(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(BACKTICKS, pegged.peg.option!(identifier), pegged.peg.discard!(eol), pegged.peg.zeroOrMore!(CodeLine), BACKTICKS, pegged.peg.discard!(pegged.peg.option!(eol))), "SlidexDoc.CodeBlock")(p);
        }
        else
        {
            if (auto m = tuple(`CodeBlock`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(BACKTICKS, pegged.peg.option!(identifier), pegged.peg.discard!(eol), pegged.peg.zeroOrMore!(CodeLine), BACKTICKS, pegged.peg.discard!(pegged.peg.option!(eol))), "SlidexDoc.CodeBlock"), "CodeBlock")(p);
                memo[tuple(`CodeBlock`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree CodeBlock(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(BACKTICKS, pegged.peg.option!(identifier), pegged.peg.discard!(eol), pegged.peg.zeroOrMore!(CodeLine), BACKTICKS, pegged.peg.discard!(pegged.peg.option!(eol))), "SlidexDoc.CodeBlock")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(BACKTICKS, pegged.peg.option!(identifier), pegged.peg.discard!(eol), pegged.peg.zeroOrMore!(CodeLine), BACKTICKS, pegged.peg.discard!(pegged.peg.option!(eol))), "SlidexDoc.CodeBlock"), "CodeBlock")(TParseTree("", false,[], s));
        }
    }
    static string CodeBlock(GetName g)
    {
        return "SlidexDoc.CodeBlock";
    }

    static TParseTree CodeLine(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(BACKTICKS), pegged.peg.negLookahead!(eol), pegged.peg.any)), eol)), "SlidexDoc.CodeLine")(p);
        }
        else
        {
            if (auto m = tuple(`CodeLine`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(BACKTICKS), pegged.peg.negLookahead!(eol), pegged.peg.any)), eol)), "SlidexDoc.CodeLine"), "CodeLine")(p);
                memo[tuple(`CodeLine`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree CodeLine(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(BACKTICKS), pegged.peg.negLookahead!(eol), pegged.peg.any)), eol)), "SlidexDoc.CodeLine")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(BACKTICKS), pegged.peg.negLookahead!(eol), pegged.peg.any)), eol)), "SlidexDoc.CodeLine"), "CodeLine")(TParseTree("", false,[], s));
        }
    }
    static string CodeLine(GetName g)
    {
        return "SlidexDoc.CodeLine";
    }

    static TParseTree BACKTICKS(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(backquote, backquote, backquote)), "SlidexDoc.BACKTICKS")(p);
        }
        else
        {
            if (auto m = tuple(`BACKTICKS`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(backquote, backquote, backquote)), "SlidexDoc.BACKTICKS"), "BACKTICKS")(p);
                memo[tuple(`BACKTICKS`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree BACKTICKS(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(backquote, backquote, backquote)), "SlidexDoc.BACKTICKS")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.and!(backquote, backquote, backquote)), "SlidexDoc.BACKTICKS"), "BACKTICKS")(TParseTree("", false,[], s));
        }
    }
    static string BACKTICKS(GetName g)
    {
        return "SlidexDoc.BACKTICKS";
    }

    static TParseTree Word(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(SpecialChar), pegged.peg.negLookahead!(blank), pegged.peg.negLookahead!(eol), pegged.peg.any))), "SlidexDoc.Word")(p);
        }
        else
        {
            if (auto m = tuple(`Word`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(SpecialChar), pegged.peg.negLookahead!(blank), pegged.peg.negLookahead!(eol), pegged.peg.any))), "SlidexDoc.Word"), "Word")(p);
                memo[tuple(`Word`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree Word(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(SpecialChar), pegged.peg.negLookahead!(blank), pegged.peg.negLookahead!(eol), pegged.peg.any))), "SlidexDoc.Word")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(SpecialChar), pegged.peg.negLookahead!(blank), pegged.peg.negLookahead!(eol), pegged.peg.any))), "SlidexDoc.Word"), "Word")(TParseTree("", false,[], s));
        }
    }
    static string Word(GetName g)
    {
        return "SlidexDoc.Word";
    }

    static TParseTree InlineWord(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(InlineSpecial), pegged.peg.negLookahead!(blank), pegged.peg.negLookahead!(eol), pegged.peg.any))), "SlidexDoc.InlineWord")(p);
        }
        else
        {
            if (auto m = tuple(`InlineWord`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(InlineSpecial), pegged.peg.negLookahead!(blank), pegged.peg.negLookahead!(eol), pegged.peg.any))), "SlidexDoc.InlineWord"), "InlineWord")(p);
                memo[tuple(`InlineWord`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree InlineWord(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(InlineSpecial), pegged.peg.negLookahead!(blank), pegged.peg.negLookahead!(eol), pegged.peg.any))), "SlidexDoc.InlineWord")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(InlineSpecial), pegged.peg.negLookahead!(blank), pegged.peg.negLookahead!(eol), pegged.peg.any))), "SlidexDoc.InlineWord"), "InlineWord")(TParseTree("", false,[], s));
        }
    }
    static string InlineWord(GetName g)
    {
        return "SlidexDoc.InlineWord";
    }

    static TParseTree SpecialChar(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\\"), pegged.peg.literal!("*"), pegged.peg.literal!("/"), pegged.peg.literal!("-"), pegged.peg.literal!("_"), pegged.peg.literal!("~"), pegged.peg.literal!("#"), pegged.peg.literal!("["), pegged.peg.literal!("$"), backquote, pegged.peg.literal!("}"), blank, eol), "SlidexDoc.SpecialChar")(p);
        }
        else
        {
            if (auto m = tuple(`SpecialChar`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\\"), pegged.peg.literal!("*"), pegged.peg.literal!("/"), pegged.peg.literal!("-"), pegged.peg.literal!("_"), pegged.peg.literal!("~"), pegged.peg.literal!("#"), pegged.peg.literal!("["), pegged.peg.literal!("$"), backquote, pegged.peg.literal!("}"), blank, eol), "SlidexDoc.SpecialChar"), "SpecialChar")(p);
                memo[tuple(`SpecialChar`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree SpecialChar(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\\"), pegged.peg.literal!("*"), pegged.peg.literal!("/"), pegged.peg.literal!("-"), pegged.peg.literal!("_"), pegged.peg.literal!("~"), pegged.peg.literal!("#"), pegged.peg.literal!("["), pegged.peg.literal!("$"), backquote, pegged.peg.literal!("}"), blank, eol), "SlidexDoc.SpecialChar")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(pegged.peg.literal!("\\"), pegged.peg.literal!("*"), pegged.peg.literal!("/"), pegged.peg.literal!("-"), pegged.peg.literal!("_"), pegged.peg.literal!("~"), pegged.peg.literal!("#"), pegged.peg.literal!("["), pegged.peg.literal!("$"), backquote, pegged.peg.literal!("}"), blank, eol), "SlidexDoc.SpecialChar"), "SpecialChar")(TParseTree("", false,[], s));
        }
    }
    static string SpecialChar(GetName g)
    {
        return "SlidexDoc.SpecialChar";
    }

    static TParseTree InlineSpecial(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(SpecialChar, pegged.peg.literal!("]")), "SlidexDoc.InlineSpecial")(p);
        }
        else
        {
            if (auto m = tuple(`InlineSpecial`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.or!(SpecialChar, pegged.peg.literal!("]")), "SlidexDoc.InlineSpecial"), "InlineSpecial")(p);
                memo[tuple(`InlineSpecial`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree InlineSpecial(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.or!(SpecialChar, pegged.peg.literal!("]")), "SlidexDoc.InlineSpecial")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.or!(SpecialChar, pegged.peg.literal!("]")), "SlidexDoc.InlineSpecial"), "InlineSpecial")(TParseTree("", false,[], s));
        }
    }
    static string InlineSpecial(GetName g)
    {
        return "SlidexDoc.InlineSpecial";
    }

    static TParseTree RTNumber(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.charRange!('0', '9'))), "SlidexDoc.RTNumber")(p);
        }
        else
        {
            if (auto m = tuple(`RTNumber`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.charRange!('0', '9'))), "SlidexDoc.RTNumber"), "RTNumber")(p);
                memo[tuple(`RTNumber`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree RTNumber(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.charRange!('0', '9'))), "SlidexDoc.RTNumber")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.fuse!(pegged.peg.oneOrMore!(pegged.peg.charRange!('0', '9'))), "SlidexDoc.RTNumber"), "RTNumber")(TParseTree("", false,[], s));
        }
    }
    static string RTNumber(GetName g)
    {
        return "SlidexDoc.RTNumber";
    }

    static TParseTree RTString(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.any))), pegged.peg.discard!(doublequote)), "SlidexDoc.RTString")(p);
        }
        else
        {
            if (auto m = tuple(`RTString`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.any))), pegged.peg.discard!(doublequote)), "SlidexDoc.RTString"), "RTString")(p);
                memo[tuple(`RTString`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree RTString(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.any))), pegged.peg.discard!(doublequote)), "SlidexDoc.RTString")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.discard!(doublequote), pegged.peg.fuse!(pegged.peg.zeroOrMore!(pegged.peg.and!(pegged.peg.negLookahead!(doublequote), pegged.peg.any))), pegged.peg.discard!(doublequote)), "SlidexDoc.RTString"), "RTString")(TParseTree("", false,[], s));
        }
    }
    static string RTString(GetName g)
    {
        return "SlidexDoc.RTString";
    }

    static TParseTree EscapedChar(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("\\"), pegged.peg.any), "SlidexDoc.EscapedChar")(p);
        }
        else
        {
            if (auto m = tuple(`EscapedChar`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("\\"), pegged.peg.any), "SlidexDoc.EscapedChar"), "EscapedChar")(p);
                memo[tuple(`EscapedChar`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree EscapedChar(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("\\"), pegged.peg.any), "SlidexDoc.EscapedChar")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.and!(pegged.peg.literal!("\\"), pegged.peg.any), "SlidexDoc.EscapedChar"), "EscapedChar")(TParseTree("", false,[], s));
        }
    }
    static string EscapedChar(GetName g)
    {
        return "SlidexDoc.EscapedChar";
    }

    static TParseTree LineBreak(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(endOfLine, "SlidexDoc.LineBreak")(p);
        }
        else
        {
            if (auto m = tuple(`LineBreak`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(endOfLine, "SlidexDoc.LineBreak"), "LineBreak")(p);
                memo[tuple(`LineBreak`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree LineBreak(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(endOfLine, "SlidexDoc.LineBreak")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(endOfLine, "SlidexDoc.LineBreak"), "LineBreak")(TParseTree("", false,[], s));
        }
    }
    static string LineBreak(GetName g)
    {
        return "SlidexDoc.LineBreak";
    }

    static TParseTree WS(TParseTree p)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.discard!(pegged.peg.zeroOrMore!(blank)), "SlidexDoc.WS")(p);
        }
        else
        {
            if (auto m = tuple(`WS`, p.end) in memo)
                return *m;
            else
            {
                TParseTree result = hooked!(pegged.peg.defined!(pegged.peg.discard!(pegged.peg.zeroOrMore!(blank)), "SlidexDoc.WS"), "WS")(p);
                memo[tuple(`WS`, p.end)] = result;
                return result;
            }
        }
    }

    static TParseTree WS(string s)
    {
        if(__ctfe)
        {
            return         pegged.peg.defined!(pegged.peg.discard!(pegged.peg.zeroOrMore!(blank)), "SlidexDoc.WS")(TParseTree("", false,[], s));
        }
        else
        {
            forgetMemo();
            return hooked!(pegged.peg.defined!(pegged.peg.discard!(pegged.peg.zeroOrMore!(blank)), "SlidexDoc.WS"), "WS")(TParseTree("", false,[], s));
        }
    }
    static string WS(GetName g)
    {
        return "SlidexDoc.WS";
    }

    static TParseTree opCall(TParseTree p)
    {
        TParseTree result = decimateTree(SlideDeck(p));
        result.children = [result];
        result.name = "SlidexDoc";
        return result;
    }

    static TParseTree opCall(string input)
    {
        if(__ctfe)
        {
            return SlidexDoc(TParseTree(``, false, [], input, 0, 0));
        }
        else
        {
            forgetMemo();
            return SlidexDoc(TParseTree(``, false, [], input, 0, 0));
        }
    }
    static string opCall(GetName g)
    {
        return "SlidexDoc";
    }


    static void forgetMemo()
    {
        memo = null;
    }
    }
}

alias GenericSlidexDoc!(ParseTree).SlidexDoc SlidexDoc;

