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
                return parseBold(child);
            case "SlidexDoc.Italic":
                return parseItalic(child);
            case "SlidexDoc.Underline":
                return parseUnderline(child);
            case "SlidexDoc.Strike":
                assert(false, "Not implemented strike");
                break;
            case "SlidexDoc.SmallCaps":
                assert(false, "Not implemented smallcaps");
                break;
            case "SlidexDoc.Variable":
                return parseVariable(child);
            case "SlidexDoc.Word":
                return parseWord(child);
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
    Result!TextItem parseBold(ParseTree root) {
        Result!TextItem result = Result!TextItem(ok: true);
        Bold bold;
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

    Result!TextItem parseItalic(ParseTree root) {
        Result!TextItem result = Result!TextItem(ok: true);
        Italic italic;
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

    Result!TextItem parseUnderline(ParseTree root) {
        Result!TextItem result = Result!TextItem(ok: true);
        Underline underline;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.InlineContent":
                Result!(TextItem[]) res = parseInlineContent(child);
                result.absorb(res).ifSome((ti) { underline.items ~= ti; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = underline;
        return result;
    }
    // Result!parseStrike(ParseTree root) {
    // }
    // Result!parseSmallCaps(ParseTree root) {
    // }
    Result!TextItem parseVariable(ParseTree root) {
        TextItem v = Variable(root.matches[1]);
        return Result!TextItem(ok: true, value: v);
    }

    Result!TextItem parseWord(ParseTree root) {
        TextItem w = Word(root.matches[0]);
        return Result!TextItem(ok: true, value: w);
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
                return parseBold(child);
            case "SlidexDoc.Italic":
                return parseItalic(child);
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
                return parseVariable(child);
            case "SlidexDoc.InlineWord":
                return parseInlineWord(child);
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
        TextItem ti = Word(root.matches[0]);
        return Result!TextItem(ok: true, value: ti);
    }
    // Result!parseRTNumber(ParseTree root) {
    // }
    // Result!parseRTString(ParseTree root) {
    // }

}
