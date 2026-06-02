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

// import gst.types;
// import gst1.gstreamer;
import gst.element;
import gst.element_factory;

import gtk.overlay;
import gtk.widget;
import gtk.types;

import gobject.value;

import pango.attribute;
import pango.attr_list;
import pango.font_description;
import pango.layout;

import slides;
import types;

// import std.bitmanip;

bool isVideo;

// enum BULLET = "➤ ";
enum BULLET = "• ";

struct Size {
    float x;
    float y;
    float w;
    float h;
}

class RichTextDrawingVisitor : RichTextVisitor {
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

    Text text;
    Size size;
    Variant[string] vartable;

    this(Text text, Size size, float factor, Variant[string] vartable) {

        this.text = text;
        this.size = size;
        this.factor = factor;
        this.vartable = vartable;

        // PgCairo.contextSetResolution(PgCairo.createContext(context),72);

    }

    void startLayout() {
        // create the first layout
        layout = PgCairo.createLayout(context);
        layout.setWidth(cast(int)(size.w * PANGO_SCALE));
        // TODO: get default font from master.
        PgFontDescription fd = new PgFontDescription("Roboto", cast(int)(text.size * factor));
        // fd.setWeight(PangoWeight.BOLD);
        layout.setFontDescription(fd);
        if (attrList)
            attrList.destroy();
        attrList = new PgAttributeList();
    }

    // Add more parameters instead of using class fields.
    void outputLayout(string text) {

        if (text.length == 0)
            return;

        writeln("SIZE: ", size);

        float x = size.x + offsetx;
        float y = size.y + offsety;
        float w = size.w;
        float h = size.h;

        // when done print the text.
        layout.setText(text);
        layout.setAttributes(attrList);

        PangoRectangle inkRect, logicalRect;

        layout.getPixelExtents(inkRect, logicalRect);
        writeln(i"Planned:    x:$(x),y:$(y),w:$(w),h:$(h)");
        writeln(i"inkt rect:  x:$(inkRect.x),y:$(inkRect.y),w:$(inkRect.width),h:$(inkRect.height)");
        writeln(i"logic rect: x:$(logicalRect.x),y:$(logicalRect.y),w:$(logicalRect.width),h:$(
                logicalRect.height)");

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
            PgCairo.showLayout(context, layout);

            if (showDebugOverlay) {
                setLineWidth(1);
                rectangle(x, y, logicalRect.width, logicalRect.height);
                setSourceRgb(0.85, 0.6, 0.6);
                stroke();
            }
        }

        offsety += logicalRect.height;

    }

    void paint(Context context) {
        this.context = context;

        // create a new layout
        startLayout();

        text.content.accept(this);

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

    void visit(RichText richtext) {
        result = appender!string;

    }

    void visit(TextItem textitem) {
    }

    void visit(EscapedChar ec) {
        switch (ec.letter) {
        case 'n':
            result ~= char(0x0a); // Line feed
            break;
        default:
            result ~= ec.letter ~ " ";
        }
    }

    void visit(ParaBreak pb) {
        outputLayout(result.data());
        result = appender!string();
        offsety += 18 * factor; // 10 pixels between paragraphs
        startLayout();
    }

    void visit(Word word) {
        result ~= word.text ~ " ";
        count += word.text.length + 1;
    }

    void enter(Bold bold) {
        currentAttr = PgAttribute.weightNew(PangoWeight.BOLD);
        currentAttr.getPgAttributeStruct().startIndex = count;
    }

    void leave(Bold bold) {
        currentAttr.getPgAttributeStruct().endIndex = count;
        attrList.insert(currentAttr);
        currentAttr = null;
    }

    void enter(Italic italic) {
        currentAttr = PgAttribute.styleNew(PangoStyle.ITALIC);
        currentAttr.getPgAttributeStruct().startIndex = count;
    }

    void leave(Italic italic) {
        currentAttr.getPgAttributeStruct().endIndex = count;
        attrList.insert(currentAttr);
        // currentAttr.destroy();
        currentAttr = null;
    }

    void enter(Underline underline) {
        currentAttr = PgAttribute.underlineNew(PangoUnderline.SINGLE);
        currentAttr.getPgAttributeStruct().startIndex = count;
    }

    void leave(Underline underline) {
        currentAttr.getPgAttributeStruct().endIndex = count;
        attrList.insert(currentAttr);
        // currentAttr.destroy();
        currentAttr = null;
    }

    void visit(Variable variable) {
        writeln("Variable: ", variable);
        result ~= vartable[variable.name].to!string ~ " ";
    }

    void visit(Func func) {
    }

    void enter(ListBlock listblock) {
    }

    void leave(ListBlock listblock) {
        outputLayout(result.data());
        result = appender!string();
        startLayout();
    }

    void enter(ListItem listitem) {
        outputLayout(result.data());
        result = appender!string();
        startLayout();
        // TODO: instead of offsetx and offsetx, can I use translate instead?
        offsetx = listitem.level * 15;
        layout.setIndent(-40 * PANGO_SCALE);
        layout.setWidth(cast(int)((size.w - listitem.level * 15) * PANGO_SCALE));

        result ~= BULLET;
    }

    void leave(ListItem listitem) {
        outputLayout(result.data());
        result = appender!string();
        startLayout();
        offsetx = listitem.level * 15;
        layout.setIndent(listitem.level > 1 ? -40 * PANGO_SCALE : 0);
        layout.setWidth(cast(int)((size.w - listitem.level * 15) * PANGO_SCALE));
    }

    void visit(Code code) {
    }

}

class GtkDrawingVisitor : ItemVisitor {
    Context context;
    Allocation size;
    TextExtents extents;

    bool showDebugOverlay;

    float[] colsizes;
    float[] rowsizes;

    Variant[string] vartable;

    float factor;

    this(Context context, Widget w, Variant[string] vartable) {
        this.context = context;
        this.vartable = vartable;
        w.getAllocation(size);
    }

    void visit(Master master) {

        // calculate columns and row sizes
        master.columns.match!(
            (int numcols) {
            colsizes.length = numcols;
            colsizes[] = size.width / cast(float) numcols;
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
                    colsizes[i] = (size.width - fixedSum) * dim.value / fractionSum;
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
            rowsizes[] = size.height / cast(float) numrows;
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
                    rowsizes[i] = (size.height - fixedSum) * dim.value / fractionSum;
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
                    lineTo(x, size.height - 1);
                }
                float y = 0;
                for (size_t i = 0; i < rowsizes.length - 1; i++) {
                    y += rowsizes[i];
                    moveTo(0, y);
                    lineTo(size.width - 1, y);
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

    void visit(Item item) {
        // writeln("TODO: drawing item skipped. it is abstract");
    }

    void visit(Rect rect) {
        // writeln("TODO: drawing rect");

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
        // writeln("Drawing image: ", image.path);
        ImageSurface surface = ImageSurface.createFromPng(image.path);

        // factor out
        float x, y, w, h, a;
        image.layoutLocation.match!(
            (BoundsLocation bl) {
            x = bl.x;
            y = bl.y;
            w = bl.width;
            h = bl.height;
            a = bl.angle;
        },
            (CellLocation cl) {
            assert(false, "CellLocation is not implemented for Image");
        }
        );
        writeln(i"Image pos: x:$(x), y:$(y), w:$(w), h:$(h), a:$(a)");

        float img_w = surface.getWidth();
        float img_h = surface.getHeight();

        with (context) {
            save();
            float midpointx = w / 2.0;
            float midpointy = h / 2.0;
            translate(x * factor + midpointx, y * factor + midpointy);
            rotate(a);
            translate(-midpointx, -midpointy);
            scale(w / img_w * factor, w / img_w * factor);
            setSourceSurface(surface, 0, 0);
            paint();
            restore();
        }

    }

    void visit(Video video) {
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

        RichTextDrawingVisitor rtv = new RichTextDrawingVisitor(text, Size(x, y, w, h), factor, vartable);
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
        overlay.addOnGetChildPosition((widget, alloc, self) {
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

        playbin.setState(GstState.PLAYING);
    }

    void visit(Text text) {
    }

}
