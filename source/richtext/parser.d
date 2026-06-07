module richtext.parser;

import std.array;
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
            case "SlidexDoc.CodeBlock":
                return parseCodeBlock(child);
            case "SlidexDoc.ListBlock":
                return parseListBlock(child);
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
            case "SlidexDoc.EscapedChar":
                return parseEscapedChar(child);
            case "SlidexDoc.LineBreak":
                TextItem ti = LineBreak(child.matches.join());
                return Result!TextItem(ok: true, value: ti);
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        assert(false, "Unreachable");
    }

    Result!TextItem parseCodeBlock(ParseTree root) {
        Result!TextItem result = Result!TextItem(ok: true);
        Code code;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.BACKTICKS":
                break;
            case "SlidexDoc.CodeLine":
                code.lines ~= child.matches[0];
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = code;
        return result;
    }

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

    Result!TextItem parseEscapedChar(ParseTree root) {
        // TODO: this may cause unicode problems
        TextItem ec = EscapedChar(root.matches[1][0]);
        return Result!TextItem(ok: true, value: ec);
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
            case "SlidexDoc.EscapedChar":
                return parseEscapedChar(child);
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        writeln("parseInlineNode(): ", root);
        assert(false, "Unreachable");
    }

    Result!TextItem parseListBlock(ParseTree root) {
        Result!TextItem result = Result!TextItem(ok: true);
        ListBlock block;

        // writeln("ListBlock: ", root);
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.ListItem":
                Result!ListItem res = parseListItem(child);
                result.absorb(res).ifSome((li) { block.items ~= li; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        // normalize indents
        uint minspaces = uint.max;
        foreach (item; block.items) {
            if (minspaces > item.level)
                minspaces = item.level;
        }
        foreach (ref item; block.items) {
            item.level -= minspaces;
        }
        result.value = block;
        return result;

    }

    Result!ListItem parseListItem(ParseTree root) {
        Result!ListItem result = Result!ListItem(ok: true);
        ListItem item;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.BulletMarker":
                size_t i = 0;
                while (i < child.matches.length && child.matches[i] == " ") {
                    item.level++;
                    i++;
                }
                item.bullet = child.matches[i][0];
                break;
            case "SlidexDoc.ListItemContent":
                Result!(TextItem[]) res = parseListItemContent(child);
                result.absorb(res).ifSome((ti) { item.content = ti; });
                break;
            default:
                assert(false, "Unknown node: " ~ child.name);
            }
        }
        result.value = item;
        return result;
    }

    Result!(TextItem[]) parseListItemContent(ParseTree root) {
        Result!(TextItem[]) result = Result!(TextItem[])(ok: true);
        TextItem[] items;
        foreach (child; root.children) {
            switch (child.name) {
            case "SlidexDoc.ListItemNode":
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
