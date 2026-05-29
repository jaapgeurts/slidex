module rendering;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.sumtype;
import std.variant;

import cairo.Context;
import cairo.ImageSurface;
import cairo.Surface;

import gstreamer.GStreamer;
import gstreamer.Element;
import gstreamer.ElementFactory;

import gtk.Overlay;
import gtk.Widget;

import gobject.Value;

import pango.PgAttribute;
import pango.PgAttributeList;
import pango.PgCairo;
import pango.PgFontDescription;
import pango.PgLayout;

import slides;
import types;
// import std.bitmanip;

bool isVideo;

class RichTextToPangoConvertorVistor : RichTextVisitor {
    Appender!string result;
    uint count;
    PgAttributeList attrList;
    PgAttribute currentAttr;
    uint slidenum;
    uint totalnum;

    Variant[string] vartable;

    this(Variant[string] vartable) {
        this.vartable = vartable;
    }

    void visit(RichText richtext) {
        result = appender!string;
        attrList = new PgAttributeList();
    }

    void visit(TextItem textitem) {
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

    void visit(List list) {
    }

    void visit(Code code) {
    }

}

class GtkDrawingVisitor : ItemVisitor {
    Context context;
    GtkAllocation size;
    cairo_text_extents_t extents;

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
                    colsizes[i] = dim.value;
                    fixedSum += dim.value;
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
                    colsizes[i] = (size.width - fixedSum) * dim.value / cast(float) fractionSum;
                i++;
            }

            writeln("Dims:     ", dims);
            writeln("Colsizes: ", colsizes);
            // assert(false, "column sizes calculation not implemented yet");
        }
        );
        writeln("ROWS: ", master.rows);
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
                    rowsizes[i] = dim.value;
                    fixedSum += dim.value;
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
                    rowsizes[i] = (size.height - fixedSum) * dim.value / cast(float) fractionSum;
                i++;
            }

            writeln("Dims:     ", dims);
            writeln("Rowsizes: ", rowsizes);
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
        float x, y, w, h;
        image.layoutLocation.match!(
            (BoundsLocation bl) { x = bl.x; y = bl.y; w = bl.width; h = bl.height; },
            (CellLocation cl) {
            assert(false, "CellLocation is not implemented for Image");
        }
        );

        float img_w = surface.getWidth();
        float img_h = surface.getHeight();

        with (context) {
            save();
            translate(x * factor, y * factor);
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

        // PgCairo.contextSetResolution(PgCairo.createContext(context),72);

        PgLayout layout = PgCairo.createLayout(context);
        layout.setWidth(cast(int)(w * PANGO_SCALE));

        // TODO: move out of this visitor
        RichTextToPangoConvertorVistor rtv = new RichTextToPangoConvertorVistor(vartable);
        text.content.accept(rtv);
        string content = rtv.result.data();
        writeln("CONTENT: ", content);

        layout.setText(content);
        layout.setAttributes(rtv.attrList);
        PgFontDescription fd = new PgFontDescription("Roboto", cast(int)(text.size * factor));
        // fd.setWeight(PangoWeight.BOLD);
        layout.setFontDescription(fd);
        PangoRectangle inkRect, logicalRect;

        layout.getPixelExtents(inkRect, logicalRect);

        with (context) {
            // TODO: auto convert rgb colour to float triplet
            setSourceRgb(text.colour.r / 255.0, text.colour.g / 255.0, text.colour.b / 255.0);
            // textExtents(text.content, &extents);
            // TODO: implement text box alignment
            moveTo(x + logicalRect.x, y + logicalRect.y);
            // showText(text.content);
            PgCairo.showLayout(context, layout);

            if (showDebugOverlay) {
                setLineWidth(2);
                rectangle(x, y, w, h);
                stroke();
            }
        }

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
