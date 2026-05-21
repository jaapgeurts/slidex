module presenter;

import std.stdio;
import std.sumtype;
import std.typecons;

import cairo.Context;
import cairo.ImageSurface;
import cairo.Surface;

import gtk.MainWindow;
import gtk.Main;
import gtk.Widget;

import gdk.Event;
import gdk.Keymap;
import gdk.Keysyms;

import gstreamer.Pipeline;

import pango.PgCairo;
import pango.PgLayout;

import slides;
import types;
import pango.PgFontDescription;
import pango.c.functions;
import core.stdc.ctype;

class GtkDrawingVisitor : ItemVisitor {
    Context context;
    GtkAllocation size;
    cairo_text_extents_t extents;

    bool showDebugOverlay;

    float colwidth;
    float rowheight;

    float factor;

    this(Context context, Widget w) {
        this.context = context;
        w.getAllocation(size);

    }

    void visit(Master master) {
        writeln("TODO: drawing for master data (e.g. setup grid)");
        colwidth = size.width / cast(float) master.columns;
        rowheight = size.height / cast(float) master.rows;

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
                for (size_t x = 1; x < master.columns; x++) {
                    moveTo(x * colwidth, 0);
                    lineTo(x * colwidth, size.height - 1);
                }
                for (size_t y = 1; y < master.rows; y++) {
                    moveTo(0, y * rowheight);
                    lineTo(size.width - 1, y * rowheight);
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
        writeln("TODO: drawing item skipped. it is abstract");
    }

    void visit(Rect rect) {
        writeln("TODO: drawing rect");

        float x, y, w, h;
        rect.layoutLocation.match!(
            (BoundsLocation bl) {

            assert(false, "Rect bounds location not implemented");
        },
            (CellLocation cl) {
            x = cl.col * colwidth + cl.dx;
            y = cl.row * rowheight + cl.dy;
            w = cl.colspan * colwidth;
            h = cl.rowspan * rowheight;
        });

        with (context) {
            writeln("FILL: ", rect.fill);
            // assert(false, "color parsing needs fix");
            setSourceRgb(rect.fill.r / 255.0, rect.fill.g / 255.0, rect.fill.b / 255.0);
            setLineWidth(5);
            rectangle(x, y, w, h);
            fill();
        }
    }

    void visit(Image image) {
        writeln("Drawing image: ", image.path);
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
        writeln("Drawing movie: ", movie.path);

        // factor out
        float x, y, w, h;
        movie.layoutLocation.match!(
            (BoundsLocation bl) { x = bl.x; y = bl.y; w = bl.width; h = bl.height; },
            (CellLocation cl) {
            assert(false, "CellLocation is not implemented for Movie");
        }
        );

        float img_w = 100; //surface.getWidth();
        float img_h = 100; //surface.getHeight();

        with (context) {

            if (showDebugOverlay) {
                setLineWidth(2);
                rectangle(x, y, w, h);
                stroke();
            }
        }

    }

    void visit(Text text) {
        writeln("TODO: drawing text");

        float x, y, w, h;
        text.layoutLocation.match!(
            (BoundsLocation bl) {
            assert(false, "Text bounds location not implemented");
        },
            (CellLocation cl) {
            x = cl.col * colwidth + cl.dx;
            y = cl.row * rowheight + cl.dy;
            w = cl.colspan * colwidth;
            h = cl.rowspan * rowheight;
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

void presentDeck(string[] args, Deck deck) {
    // writeln("Slide:  ", deck.slides[0].toString);
    // writeln("Master: ", deck.slides[0].master.toString);
    // writeln("DECK: ", deck.slides[0].master.items[0].visible);
    // open the gtk window

    Main.init(args);

    Presenter presenter = new Presenter(deck, args);

    Main.run();

}

class Presenter {
    size_t currentSlide = 0;
    bool isFullScreen = false;
    bool isBlanking = false;
    bool isDebugOverlay = false;
    float factor = 1.0;
    // TODO: move this window to local var??
    MainWindow projectorWin;

    GtkAllocation size;

    Deck deck;

    Keymap keymap;

    this(Deck deck, string[] args) {

        this.deck = deck;
        isDebugOverlay = args.length > 2 && args[2] == "debug";

        projectorWin = new MainWindow("Projector",);
        projectorWin.setSizeRequest(960, 600);
        projectorWin.addOnDestroy(&onQuit);

        projectorWin.addOnDraw(&onDraw);
        projectorWin.addOnKeyPress(&onKeyPress);
        projectorWin.addOnButtonPress(&onMousePress);
        projectorWin.addOnSizeAllocate(&onSizeAllocate);

        projectorWin.showAll();

        // Display myDisplay = Display.getDefault();
        // Seat seat = myDisplay.getDefaultSeat();
        // Device keyboard = seat.getKeyboard();
        keymap = Keymap.getDefault();

    }

    void onQuit(Widget w) {

        writeln("Quitting");
        Main.quit();
    }

    bool onDraw(Scoped!Context context, Widget w) {

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
            foreach (item; slide.master.items)
                item.accept(drawing);
            foreach (item; slide.items)
                item.accept(drawing);
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
                projectorWin.unfullscreen();
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
                projectorWin.queueDraw();
            }
        }
        else if (eventKey.keyval == GdkKeysyms.GDK_F11) {
            if (!isFullScreen) {
                // TODO: move into function
                isBlanking = false;
                projectorWin.fullscreen();
                isFullScreen = true;
            }
            else {
                projectorWin.unfullscreen();
                isFullScreen = false;
            }
        }
        if (oldCurrentSlide != currentSlide)
            projectorWin.queueDraw();

        return true;

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
