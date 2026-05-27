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
        Result!RichText result = Result!RichText(ok: true);

        RichText rt = new RichText();
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.RichTextNode":
                Result!TextItem res = parseRichTextNode(child);
                result.absorb(res).ifSome((w) { rt.items ~= w; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = rt;
        return result;
    }

private:
    Result!TextItem parseRichTextNode(ParseTree root) {

        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.ParaBreak":
                assert(false, "Not implemented parabreak");
                break;
            case "SlidexDoc.CodeBlock":
                assert(false, "Not implemented codeblock");
                break;
            case "SlidexDoc.ListBlock":
                assert(false, "Not implemented listblock");
                break;
            case "SlidexDoc.Func":
                assert(false, "Not implemented func");
                break;
            case "SlidexDoc.Bold":
                return cast(Result!TextItem) parseBold(child);
            case "SlidexDoc.Italic":
                return cast(Result!TextItem) parseItalic(child);
                break;
            case "SlidexDoc.Underline":
                assert(false, "Not implemented underline");
                break;
            case "SlidexDoc.Strike":
                assert(false, "Not implemented strike");
                break;
            case "SlidexDoc.SmallCaps":
                assert(false, "Not implemented smallcaps");
                break;
            case "SlidexDoc.Variable":
                assert(false, "Not implemented variable");
                break;
            case "SlidexDoc.Word":
                return cast(Result!TextItem) parseWord(child);
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        assert(false, "Unreachable");
    }

    // Result!parseParaBreak(ParseTree root) {
    // }
    // Result!parseCodeBLock(ParseTree root) {
    // }
    // Result!parseListBlock(ParseTree root) {
    // }
    // Result!parseFunc(ParseTree root) {
    // }
    Result!Bold parseBold(ParseTree root) {
        Result!Bold result = Result!Bold(ok: true);
        Bold bold = new Bold();
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.InlineContent":
                Result!(TextItem[]) res = parseInlineContent(child);
                result.absorb(res).ifSome((ti) { bold.items ~= ti; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = bold;
        return result;
    }

    Result!Italic parseItalic(ParseTree root) {
        Result!Italic result = Result!Italic(ok: true);
        Italic italic = new Italic();
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.InlineContent":
                Result!(TextItem[]) res = parseInlineContent(child);
                result.absorb(res).ifSome((ti) { italic.items ~= ti; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = italic;
        return result;
    }
    // Result!parseUnderline(ParseTree root) {
    // }
    // Result!parseStrike(ParseTree root) {
    // }
    // Result!parseSmallCaps(ParseTree root) {
    // }
    // Result!parseVariable(ParseTree root) {
    // }

    Result!Word parseWord(ParseTree root) {
        return Result!Word(ok: true, value: new Word(root.matches[0]));
    }

    // Result!parseFuncName(ParseTree root) {
    // }
    // Result!parseFuncArgs(ParseTree root) {
    // }
    // Result!parseFuncArg(ParseTree root) {
    // }
    Result!(TextItem[]) parseInlineContent(ParseTree root) {
        Result!(TextItem[]) result = Result!(TextItem[])(ok: true);
        TextItem[] items;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.InlineNode":
                Result!TextItem res = parseInlineNode(child);
                result.absorb(res).ifSome((ti) { items ~= ti; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = items;
        return result;
    }

    Result!TextItem parseInlineNode(ParseTree root) {
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.Func":
                assert(false, "func not implemented");
                break;
            case "SlidexDoc.Bold":
                return cast(Result!TextItem) parseBold(child);
            case "SlidexDoc.Italic":
                assert(false, "italic not implemented");
                break;
            case "SlidexDoc.Underline":
                assert(false, "underline not implemented");
                break;
            case "SlidexDoc.Strike":
                assert(false, "strike not implemented");
                break;
            case "SlidexDoc.SmallCaps":
                assert(false, "smallcaps not implemented");
                break;
            case "SlidexDoc.Variable":
                assert(false, "variable not implemented");
                break;
            case "SlidexDoc.InlineWord":
                return cast(Result!TextItem) parseInlineWord(child);
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        assert(false, "Unreachable");
    }
    // Result!parseListItem(ParseTree root) {
    // }
    // Result!parseBulletMarker(ParseTree root) {
    // }
    // Result!parseNumberMarker(ParseTree root) {
    // }
    // Result!parseCodeLine(ParseTree root) {
    // }
    Result!TextItem parseInlineWord(ParseTree root) {
        return Result!TextItem(ok: true, value: new Word(root.matches[0]));
    }
    // Result!parseRTNumber(ParseTree root) {
    // }
    // Result!parseRTString(ParseTree root) {
    // }

}
