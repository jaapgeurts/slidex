module presenter;

import std.algorithm.iteration;
import std.stdio;
import std.sumtype;
import std.typecons;

import core.stdc.ctype;

import cairo.Context;
import cairo.ImageSurface;
import cairo.Surface;

import gtk.DrawingArea;
import gtk.Main;
import gtk.MainWindow;
import gtk.Overlay;
import gtk.Widget;

import gobject.Value;

import gdk.Event;
import gdk.Keymap;
import gdk.Keysyms;

import gstreamer.GStreamer;
import gstreamer.Element;
import gstreamer.ElementFactory;

import pango.c.functions;
import pango.PgCairo;
import pango.PgFontDescription;
import pango.PgLayout;

import slides;
import types;

bool isVideo;

class GtkDrawingVisitor : ItemVisitor {
    Context context;
    GtkAllocation size;
    cairo_text_extents_t extents;

    bool showDebugOverlay;

    float[] colsizes;
    float[] rowsizes;

    float factor;

    this(Context context, Widget w) {
        this.context = context;
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
                
                foreach(dim; dims) {
                    if (dim.unit == DimensionUnit.Pixel) 
                        colsizes[i++] = dim.value;
                }
            writeln("COLS: ", dims);
            assert(false, "column sizes calculation not implemented yet");
        }
        );
        master.columns.match!(
            (int numrows) {
            rowsizes.length = numrows;
            rowsizes[] = size.height / cast(float) numrows;
        },
            (Length[] dims) {
            writeln("ROWS: ", dims);
            assert(false, "row sizes calculation not implemented yet");
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
                // draw grid
                setSourceRgb(0.8, 0.8, 0.8);
                setLineWidth(2);
                float x;
                for (size_t i = 0; i < colsizes.length - 1; i++) {
                    x += colsizes[i];
                    moveTo(x, 0);
                    lineTo(x, size.height - 1);
                }
                float y;
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

    void visit(Movie movie) {
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
        layout.setText(text.content);
        PgFontDescription fd = new PgFontDescription("Roboto", cast(int)(text.size * factor));
        fd.setWeight(PangoWeight.BOLD);
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

class MoviePreparationVisitor : ItemVisitor {

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

    void visit(Movie movie) {
        writeln("Prepare for movie");
        Value val = new Value();
        gtksink.getProperty("widget", val);
        auto videoWidget = cast(Widget) val.getObject();

        playbin.setProperty("video-sink", gtksink);
        playbin.setProperty("uri", "file:///home/jaapg/projects/slidex/tears-of-steel.mp4");

        float x, y, w, h;
        movie.layoutLocation.match!(
            (BoundsLocation bl) { x = bl.x; y = bl.y; w = bl.width; h = bl.height; },
            (CellLocation cl) {
            assert(false, "CellLocation is not implemented for Movie");
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

void presentDeck(string[] args, Deck deck) {
    // writeln("Slide:  ", deck.slides[0].toString);
    // writeln("Master: ", deck.slides[0].master.toString);
    // writeln("DECK: ", deck.slides[0].master.items[0].visible);
    // open the gtk window

    Main.init(args);

    GStreamer.init(args);

    MainWindow projectorWin = new MainWindow("Projector",);
    projectorWin.setSizeRequest(960, 600);

    Overlay overlay = new Overlay();
    projectorWin.add(overlay);

    Presenter presenter = new Presenter(overlay, deck, args);
    presenter.setSizeRequest(960, 600);
    presenter.onFullsceen = (widget) { projectorWin.fullscreen(); };
    presenter.onUnFullsceen = (widget) { projectorWin.unfullscreen(); };

    overlay.add(presenter);

    projectorWin.addOnDestroy((Widget w) { writeln("Quitting"); Main.quit(); });
    projectorWin.addOnKeyPress(&presenter.onKeyPress);

    projectorWin.showAll();

    Main.run();

}

class Presenter : DrawingArea {
    size_t currentSlide = 0;
    bool isFullScreen = false;
    bool isBlanking = false;
    bool isDebugOverlay = false;
    float factor = 1.0;

    Overlay overlay;
    GtkAllocation size;
    Keymap keymap;

    void delegate(Widget w) onFullsceen;
    void delegate(Widget w) onUnFullsceen;

    Deck deck;

    this(Overlay overlay, Deck deck, string[] args) {

        this.overlay = overlay;
        this.deck = deck;
        isDebugOverlay = args.length > 2 && args[2] == "debug";

        addOnDraw(&onDraw);
        addOnButtonPress(&onMousePress);
        addOnSizeAllocate(&onSizeAllocate);

        // projectorWin.getRootWindow().flush();
        // Display myDisplay = Display.getDefault();
        // Seat seat = myDisplay.getDefaultSeat();
        // Device keyboard = seat.getKeyboard();
        keymap = Keymap.getDefault();

    }

    bool onDraw(Scoped!Context context, Widget w) {

        if (isVideo)
            return true;

        if (isBlanking) {
            context.setSourceRgb(0, 0, 0);
            context.paint();
            return true;
        }
        GtkDrawingVisitor drawing = new GtkDrawingVisitor(context, w);
        drawing.showDebugOverlay = isDebugOverlay;

        drawing.factor = factor;

        if (deck.slides.length == 0) {
            writeln("No slides to show");
        }
        else if (currentSlide == deck.slides.length) {
            drawEndOfPresentation(context);
        }
        else {
            Slide slide = deck.slides[currentSlide];
            slide.master.accept(drawing);
            slide.accept(drawing);
        }
        return true;
    }

    bool onKeyPress(GdkEventKey* eventKey, Widget widget) {
        string pressedKey;
        int keys;

        pressedKey = keymap.keyvalName(eventKey.keyval);
        // writeln("The keyval is: ", eventKey.keyval, " which means the ", pressedKey, " was pressed.");

        size_t oldCurrentSlide = currentSlide;
        if (eventKey.keyval == GdkKeysyms.GDK_space || eventKey.keyval == GdkKeysyms.GDK_Right) {
            if (currentSlide < deck.slides.length)
                currentSlide++;
            else
                writeln("Reached last slide");
        }
        else if (eventKey.keyval == GdkKeysyms.GDK_Left) {
            if (currentSlide > 0)
                currentSlide--;
            else
                writeln("Reached first slide");
        }
        else if (eventKey.keyval == GdkKeysyms.GDK_Escape) {
            if (isFullScreen) {
                // TODO: move into function
                if (onUnFullsceen !is null)
                    onUnFullsceen(this);
                isFullScreen = false;
            }
            else {
                Main.quit();
            }
        }
        else if (eventKey.keyval == GdkKeysyms.GDK_b) {
            if (isFullScreen) {
                // TODO: move into function
                isBlanking = !isBlanking;
                queueDraw();
            }
        }
        else if (eventKey.keyval == GdkKeysyms.GDK_F11) {
            if (!isFullScreen) {
                // TODO: move into function
                isBlanking = false;
                if (onFullsceen !is null)
                    onFullsceen(this);
                isFullScreen = true;
            }
            else {
                if (onUnFullsceen !is null)
                    onUnFullsceen(this);
                isFullScreen = false;
            }
        }

        if (oldCurrentSlide != currentSlide) {
            // TODO: move next line away from here.
            firePrepareSlideForMovie();
            queueDraw();
        }

        return true;

    }

    private void firePrepareSlideForMovie() {

        MoviePreparationVisitor prepmovie = new MoviePreparationVisitor(overlay);

        if (deck.slides.length == 0 || currentSlide == deck.slides.length) {
            writeln("No slides to show");
        }
        else {
            Slide slide = deck.slides[currentSlide];
            slide.master.accept(prepmovie);
            slide.accept(prepmovie);
        }
    }

    bool onMousePress(Event event, Widget widget) {
        bool returnValue = false;

        if (event.type == gdk.Event.EventType.BUTTON_PRESS) {
            GdkEventButton* mouseEvent = event.button;
            writeln("Mouse click: ", mouseEvent.button);
            returnValue = true;
        }

        return (returnValue);

    }

    void onSizeAllocate(Allocation newSize, Widget) {

        size = *newSize;
        factor = newSize.width / 920.0;
    }

    void drawEndOfPresentation(Context context) {
        cairo_text_extents_t extents;
        // Set background to black
        with (context) {
            setSourceRgb(0, 0, 0);
            paint();
            string endMessage = "End of presentation";
            textExtents(endMessage, &extents);
            moveTo(size.width / 2 - extents.width / 2, size.height - 20);
            setSourceRgb(1, 1, 1);
            showText(endMessage);
        }
    }

}
