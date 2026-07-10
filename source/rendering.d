module rendering;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.sumtype;
import std.variant;

import cairo.context;
import cairo.surface;
import cairo.types;
import cairo.global;

// import gst.types;
// import gst.gstreamer;
import gst.element;
import gst.element_factory;
import gst.c.types : GstState;

import gtk.overlay;
import gtk.widget;
import gtk.types;

import gobject.value;

import pango.attr_list;
import pango.attribute;
import pango.font_description;
import pango.layout;
import pango.types;
import pango.global;

import pangocairo.global;

import common;
import sharedvars;
import slides;
import syntect;
import types;

// import std.bitmanip;

bool isVideo;

// enum BULLET = "➤ ";
enum BULLET = "• ";

class RichTextRenderer {
    Text text;

    Appender!string result;
    uint count;
    bool showDebugOverlay;
    Layout layout;
    AttrList attrList;
    Attribute currentAttr;
    Context context;
    float offsety = 0;
    float offsetx = 0;
    float factor;
    uint slidenum;
    uint totalnum;

    Allocation size;
    SharedVariables vartable;

    this(Text text, Allocation size, float factor, SharedVariables vartable) {

        this.text = text;
        this.size = size;
        this.factor = factor;
        this.vartable = vartable;

    }

    void startLayout() {
        // create the first layout
        layout = createLayout(context);
        layout.setWidth(cast(int)(size.width * SCALE));
        // TODO: get default font from master.
        FontDescription fd = new FontDescription();
        fd.setFamily("Libertinus Sans");
        fd.setSize(cast(int)(text.size * factor * SCALE));
        layout.setFontDescription(fd);
        if (attrList)
            attrList.destroy();
        attrList = new AttrList();
        // attrList.insert(attrLineHeightNew(factor));
    }

    // Add more parameters instead of using class fields.
    void outputLayout(string text) {

        if (text.length == 0)
            return;

        // writeln("SIZE: ", size);
        // writeln("Text: ", text);

        float x = size.x + offsetx;
        float y = size.y + offsety;
        float w = size.width;
        float h = size.height;

        // remove final linebreak if any.
        if (text[$ - 1] == '\n')
            text = text[0 .. $ - 1];

        // when done print the text.
        layout.setText(text);
        layout.setAttributes(attrList);

        pango.types.Rectangle inkRect, logicalRect;

        layout.getPixelExtents(inkRect, logicalRect);
        // writeln(i"Planned:    x:$(x),y:$(y),w:$(w),h:$(h)");
        // writeln(i"inkt rect:  x:$(inkRect.x),y:$(inkRect.y),w:$(inkRect.width),h:$(inkRect.height)");
        // writeln(i"logic rect: x:$(logicalRect.x),y:$(logicalRect.y),w:$(logicalRect.width),h:$(
        //         logicalRect.height)");

        // TODO: pull out into function.
        this.text.layoutLocation.match!(
            (BoundsLocation bl) {
            assert(false, "Text bounds location not implemented");
        },
            (CellLocation cl) {
            final switch (cl.alignment) {
            case CellAlignment.TopLeft:
                // default calculation is TopLeft
                break;
            case CellAlignment.TopCenter:
                x += (w - logicalRect.width) / 2.0;
                break;
            case CellAlignment.TopRight:
                x += w - logicalRect.width;
                break;
            case CellAlignment.CenterLeft:
                y += (h - logicalRect.height) / 2.0;
                break;
            case CellAlignment.Center:
                x += (w - logicalRect.width) / 2.0;
                y += (h - logicalRect.height) / 2.0;
                break;
            case CellAlignment.CenterRight:
                x += w - logicalRect.width;
                y += (h - logicalRect.height) / 2.0;
                break;
            case CellAlignment.BottomLeft:
                y += h - logicalRect.height;
                break;
            case CellAlignment.BottomCenter:
                x += (w - logicalRect.width) / 2.0;
                y += h - logicalRect.height;
                break;
            case CellAlignment.BottomRight:
                x += w - logicalRect.width;
                y += h - logicalRect.height;
                break;
            }

        });

        with (context) {
            // TODO: auto convert rgb colour to float triplet
            setSourceRgb(this.text.colour.r / 255.0, this.text.colour.g / 255.0, this.text.colour.b / 255.0);
            // textExtents(text.content, &extents);
            // TODO: implement text box alignment
            moveTo(x + logicalRect.x, y + logicalRect.y);
            // showText(text.content);
            showLayout(context, layout);

            if (showDebugOverlay) {
                setLineWidth(1);
                rectangle(x, y, logicalRect.width, logicalRect.height);
                setSourceRgb(0.85, 0.6, 0.6);
                stroke();
            }
        }

        offsety += logicalRect.height;

    }

private:
    void processItem(TextItem item) {
        item.match!(
            (Word w) { result ~= w.text ~ ' '; count += w.text.length + 1; },
            (Bold b) {
            currentAttr = attrWeightNew(Weight.Bold);
            currentAttr.startIndex = count;
            foreach (i; b.items) {
                processItem(i);
            }
            currentAttr.endIndex = count;
            attrList.insert(currentAttr);
            currentAttr = null;

        },
            (Italic i) {
            currentAttr = attrStyleNew(Style.Italic);
            currentAttr.startIndex = count;
            foreach (italic; i.items) {
                processItem(italic);
            }
            currentAttr.endIndex = count;
            attrList.insert(currentAttr);
            // currentAttr.destroy();
            currentAttr = null;
        },
            (types.Underline u) {
            currentAttr = attrUnderlineNew(pango.types.Underline.Single);
            currentAttr.startIndex = count;
            foreach (i; u.items) {
                processItem(i);
            }
            currentAttr.endIndex = count;
            attrList.insert(currentAttr);
            // currentAttr.destroy();
            currentAttr = null;
        },
            (Variable v) {
            writeln("variable: ", v.name);
            result ~= vartable[v.name].to!string ~ " ";
        },
            (InlineFunc f) {
            writeln(f.name);
            assert(false, "Function appeared in items during rendering.");
        },
            (ListBlock l) {
            foreach (i; l.items) {
                startListItem(i);
                foreach (ti; i.content) {
                    processItem(ti);
                }
                endListItem(i);
            }
            outputLayout(result.data());
            result = appender!string();
            count = 0;
            startLayout();
        },
            (Code c) { startCode(c); handleCode(c); endCode(c); },
            (LineBreak lb) { result ~= '\n'; },
            (EscapedChar ec) {
            switch (ec.letter) {
            case 'n':
                result ~= char(0x0a); // Line feed
                count++;
                break;
            default:
                result ~= ec.letter;
                count++;
            }
        },
        );
    }

    void paint(Context context) {
        this.context = context;

        // create a new layout
        startLayout();

        result = appender!string;
        count = 0;
        foreach (item; text.content.items) {
            processItem(item);
        }

        /// END

        outputLayout(result.data());

        // if (text.alignment == Alignment.Left)
        //     layout.setAlignment(PangoAlignment.LEFT);
        // else if (text.alignment == Alignment.Center)
        //     layout.setAlignment(PangoAlignment.CENTER);
        // else if (text.alignment == Alignment.Right)
        //     layout.setAlignment(PangoAlignment.RIGHT);
        // else
        //     assert(false,"Only left,center and right alignments are implemented");

    }

    void startListItem(ListItem listitem) {
        outputLayout(result.data());
        result = appender!string();
        count = 0;
        startLayout();
        // TODO: instead of offsetx and offsetx, can I use translate instead?
        offsetx = listitem.level * 15;
        layout.setIndent(-40 * SCALE);
        layout.setWidth(cast(int)((size.width - listitem.level * 15) * SCALE));

        result ~= BULLET;
        count += BULLET.length;
    }

    void endListItem(ListItem listitem) {
        outputLayout(result.data());
        result = appender!string();
        count = 0;
        startLayout();
        offsetx = listitem.level * 15;
        layout.setIndent(listitem.level > 1 ? -40 * SCALE : 0);
        layout.setWidth(cast(int)((size.width - listitem.level * 15) * SCALE));
    }

    void startCode(Code code) {

        outputLayout(result.data());
        result = appender!string();
        count = 0;
        startLayout();

        FontDescription fd = new FontDescription();
        fd.setFamily("Liberation Mono");
        fd.setSize(cast(int)(text.size * factor * 0.8 * SCALE));
        layout.setFontDescription(fd);
    }

    void handleCode(Code code) {
        foreach (line; code.lines) {
            DStyleString[] coloured = highlight("C", "./light+.tmtheme", line);
            foreach (word; coloured) {
                auto a = attrForegroundNew(word.style.fg.r * 256, word.style.fg.g * 256, word.style.fg.b * 256);
                a.startIndex = count;
                result ~= word.text;
                count += word.text.length;
                a.endIndex = count;
                attrList.insert(a);
            }
        }
    }

    void endCode(Code code) {

        outputLayout(result.data());
        result = appender!string();
        count = 0;
        startLayout();
    }

}

class GtkDrawingVisitor : ItemVisitor {
    Context context;
    Size size;

    bool showDebugOverlay;
    string rootpath;

    float[] colsizes;
    float[] rowsizes;

    SharedVariables vartable;

    float factor;

    this(Context context, Size size, SharedVariables vartable, string rootpath) {
        this.context = context;
        this.vartable = vartable;
        this.size = size;
        this.rootpath = rootpath;
    }

    void mapPointToCell(Point p, uint c, uint r) {
        float sum = 0;
        c = r = 0;
        // writeln(colsizes);
        // TODO wrong because of factor.
        for (c = 0; c < colsizes.length; ++c) {
            sum += colsizes[c];
            if (p.x <= sum)
                break;
        }
        c++;
        sum = 0;
        for (r = 0; r < rowsizes.length; ++r) {
            sum += rowsizes[r];
            if (p.y <= sum)
                break;
        }
        r++;
    }

    void visit(Master master) {

        // calculate columns and row sizes
        master.columns.match!(
            (int numcols) {
            colsizes.length = numcols;
            colsizes[] = size.w / cast(float) numcols;
        },
            (Length[] dims) {
            colsizes.length = dims.length;
            float fractionSum = 0;
            float fixedSum = 0;
            size_t i;
            foreach (dim; dims) {
                if (dim.unit == DimensionUnit.Pixel) {
                    colsizes[i] = dim.value * factor;
                    fixedSum += dim.value * factor;
                }
                else if (dim.unit == DimensionUnit.Fraction) {
                    fractionSum += dim.value;
                }
                else {
                    assert(false, "Fraction `" ~ dim.unit.to!string ~ "` not implemented for column/row sizes");
                }
                i++;
            }
            i = 0;
            foreach (dim; dims) {
                if (dim.unit == DimensionUnit.Fraction) // TODO: remove hard coded size
                    colsizes[i] = (size.w - fixedSum) * dim.value / fractionSum;
                i++;
            }

            // writeln("Dims:     ", dims);
            // writeln("Colsizes: ", colsizes);
            // assert(false, "column sizes calculation not implemented yet");
        }
        );
        // writeln("ROWS: ", master.rows);
        master.rows.match!(
            (int numrows) {
            rowsizes.length = numrows;
            rowsizes[] = size.h / cast(float) numrows;
        },
            (Length[] dims) {
            rowsizes.length = dims.length;
            float fractionSum = 0;
            float fixedSum = 0;
            size_t i;
            foreach (dim; dims) {
                if (dim.unit == DimensionUnit.Pixel) {
                    rowsizes[i] = dim.value * factor;
                    fixedSum += dim.value * factor;
                }
                else if (dim.unit == DimensionUnit.Fraction) {
                    fractionSum += dim.value;
                }
                else {
                    assert(false, "Fraction `" ~ dim.unit.to!string ~ "` not implemented for column/row sizes");
                }
                i++;
            }
            i = 0;
            foreach (dim; dims) {
                if (dim.unit == DimensionUnit.Fraction) // TODO: remove hard coded size
                    rowsizes[i] = (size.h - fixedSum) * dim.value / fractionSum;
                i++;
            }

            // writeln("Dims:     ", dims);
            // writeln("Rowsizes: ", rowsizes);
            // assert(false, "column sizes calculation not implemented yet");
        }
        );

        with (context) {
            // set defaults
            // selectFontFace("Vollkorn", CairoFontSlant.NORMAL, CairoFontWeight.NORMAL);
            // setFontSize(35);

            master.background.match!(
                (RgbColour c) {
                setSourceRgb(c.r / 255.0, c.g / 255.0, c.b / 255.0);
            },
                (Image i) { assert(false, "Background images not implemented"); }
            );
            paint();

            if (showDebugOverlay) {
                // writeln("showdebug");
                // draw grid
                setSourceRgb(0.8, 0.8, 0.8);
                setLineWidth(2);
                float x = 0;
                for (size_t i = 0; i < colsizes.length - 1; i++) {
                    x += colsizes[i];
                    moveTo(x, 0);
                    lineTo(x, size.h - 1);
                }
                float y = 0;
                for (size_t i = 0; i < rowsizes.length - 1; i++) {
                    y += rowsizes[i];
                    moveTo(0, y);
                    lineTo(size.w - 1, y);
                }
                stroke();
            }
        }
    }

    void visit(Slide slide) {
        // with (context) {
        // // find the dimensions of the text so we can center it
        // setSourceRgb(0.0, 0.0, 1.0);
        // textExtents(slide.name, &extents);
        // moveTo(size.width / 2 - extents.width / 2, size.height / 2 - extents.height / 2);
        // // moveTo(50,50);
        // showText(slide.name);
        // }
    }

    void visit(Rect rect) {
        // writeln("TODO: drawing rect");

        if (!rect.visible)
            return;

        float x, y, w, h;
        rect.layoutLocation.match!(
            (BoundsLocation bl) {

            assert(false, "Rect bounds location not implemented");
        },
            (CellLocation cl) {
            x = colsizes[0 .. cl.col].sum;
            w = colsizes[cl.col .. cl.col + cl.colspan].sum;
            x += cl.dx;

            y = rowsizes[0 .. cl.row].sum;
            h = rowsizes[cl.row .. cl.row + cl.rowspan].sum;
            y += cl.dy;
        });

        with (context) {
            // writeln("FILL: ", rect.fill);
            // assert(false, "color parsing needs fix");
            setSourceRgb(rect.fill.r / 255.0, rect.fill.g / 255.0, rect.fill.b / 255.0);
            setLineWidth(5);
            rectangle(x, y, w, h);
            fill();
        }
    }

    void visit(Image image) {

        if (!image.visible)
            return;

        // writeln("Drawing image: ", rootpath ~ "/" ~ image.path);

        Surface surface = imageSurfaceCreateFromPng(rootpath ~ "/" ~ image.path);
        float img_w = imageSurfaceGetWidth(surface);
        float img_h = imageSurfaceGetHeight(surface);

        // factor out
        float x, y, w, h, a = 0;
        float sfx, sfy; // scale factor x and y
        image.layoutLocation.match!(
            (BoundsLocation bl) {
            x = bl.x * factor;
            y = bl.y * factor;
            w = bl.width * factor;
            h = bl.height * factor;
            a = bl.angle;
            sfx = sfy = w / img_w;
        },
            (CellLocation cl) {
            x = colsizes[0 .. cl.col].sum;
            w = colsizes[cl.col .. cl.col + cl.colspan].sum;
            x += cl.dx;

            y = rowsizes[0 .. cl.row].sum;
            h = rowsizes[cl.row .. cl.row + cl.rowspan].sum;
            y += cl.dy;

            sfx = w / img_w;
            sfy = h / img_h;
            if (sfx < sfy)
                sfy = sfx;
            else
                sfx = sfy;
        }
        );
        // writeln(i"Image pos: x:$(x), y:$(y), w:$(w), h:$(h), a:$(a)");
        // writeln(i"Surface size: w:$(img_w), h:$(img_h)");

        with (context) {
            save();
            translate(x, y);
            if (a != 0) {
                float midpointx = w / 2.0;
                float midpointy = h / 2.0;
                translate(midpointx, midpointy);
                rotate(a);
                translate(-midpointx, -midpointy);
            }
            scale(sfx, sfy);
            setSourceSurface(surface, 0, 0);
            paint();
            restore();
        }

    }

    void visit(Video video) {

        if (!video.visible)
            return;

        // writeln("Drawing movie: ", movie.path);

        // // factor out
        // float x, y, w, h;
        // movie.layoutLocation.match!(
        //     (BoundsLocation bl) { x = bl.x; y = bl.y; w = bl.width; h = bl.height; },
        //     (CellLocation cl) {
        //     assert(false, "CellLocation is not implemented for Movie");
        // }
        // );

        // float img_w = 100; //surface.getWidth();
        // float img_h = 100; //surface.getHeight();

        // with (context) {

        //     if (showDebugOverlay) {
        //         setLineWidth(2);
        //         rectangle(x, y, w, h);
        //         stroke();
        //     }
        // }

    }

    void visit(Text text) {

        if (!text.visible)
            return;

        // writeln("TODO: drawing text");

        float x, y, w, h;
        text.layoutLocation.match!(
            (BoundsLocation bl) {
            assert(false, "Text bounds location not implemented");
        },
            (CellLocation cl) {
            x = colsizes[0 .. cl.col].sum;
            w = colsizes[cl.col .. cl.col + cl.colspan].sum;
            x += cl.dx;

            y = rowsizes[0 .. cl.row].sum;
            h = rowsizes[cl.row .. cl.row + cl.rowspan].sum;
            y += cl.dy;

        });

        RichTextRenderer rtv = new RichTextRenderer(text, Allocation(cast(int) x, cast(int) y, cast(
                int) w, cast(int) h), factor, vartable);
        rtv.showDebugOverlay = showDebugOverlay;
        rtv.paint(context);

    }
}

class VideoPreparationVisitor : ItemVisitor {

    Element playbin;
    Element gtksink;
    Overlay overlay;

    this(Overlay overlay) {

        this.overlay = overlay;

        playbin = ElementFactory.make("playbin", "playbin");
        // create gtksink — it provides a GTK widget for embedding
        gtksink = ElementFactory.make("gtksink", "gtksink");
    }

    void visit(Slide slide) {
    }

    void visit(Master master) {
    }

    void visit(Item item) {
    }

    void visit(Rect rect) {
    }

    void visit(Image image) {
    }

    void visit(Video video) {
        writeln("Prepare for movie");
        Value val = new Value();
        gtksink.getProperty("widget", val);
        auto videoWidget = cast(Widget) val.getObject();

        playbin.setProperty("video-sink", gtksink);
        playbin.setProperty("uri", "file:///home/jaapg/projects/slidex/tears-of-steel.mp4");

        float x, y, w, h;
        video.layoutLocation.match!(
            (BoundsLocation bl) { x = bl.x; y = bl.y; w = bl.width; h = bl.height; },
            (CellLocation cl) {
            assert(false, "CellLocation is not implemented for Video");
        });

        videoWidget.setSizeRequest(cast(int) w, cast(int) h);
        overlay.connectGetChildPosition((Widget widget, out Allocation alloc, Overlay self) {
            if (widget is videoWidget) {
                writeln("set player size: x:", x, ", y:", y, ", w:", w, ", h:", h);
                alloc.x = cast(int)(x);
                alloc.y = cast(int)(y);
                alloc.width = cast(int)(w);
                alloc.height = cast(int)(h);
                return true;
            }
            return false;
        });

        overlay.addOverlay(videoWidget);

        videoWidget.show(); // show just the new widget

        isVideo = true;

        playbin.setState(GstState.Playing);
    }

    void visit(Text text) {
    }

}
