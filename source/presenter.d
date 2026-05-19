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

import gdk.Keymap;
import gdk.Keysyms;
import gdk.Event;

import slides;
import types;

class GtkDrawingVisitor : ItemVisitor {
    Context context;
    GtkAllocation size;
    cairo_text_extents_t extents;

    bool showDebugOverlay;

    int colwidth;
    int rowheight;

    this(Context context, Widget w) {
        this.context = context;
        w.getAllocation(size);

    }

    void visit(Master master) {
        writeln("TODO: drawing for master data (e.g. setup grid)");
        colwidth = size.width / master.columns;
        rowheight = size.height / master.rows;

        with (context) {
            // set defaults
            selectFontFace("Vollkorn", CairoFontSlant.NORMAL, CairoFontWeight.NORMAL);
            setFontSize(35);

            // clear surface
            setSourceRgb(1, 1, 1);
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

        int x, y, w, h;
        rect.layoutLocation.match!(
            (BoundsLocation bl) {
            assert(false, "Rect bounds location not implemented");
        },
            (CellLocation cl) {
            x = cl.col * colwidth + cl.dx;
            y = cl.row * rowheight + cl.dy;
            w = x + cl.colspan * colwidth;
            h = y + cl.rowspan * rowheight;
        });

        with (context) {
            writeln("FILL: ", rect.fill);
            // assert(false, "color parsing needs fix");
            setSourceRgb(rect.fill.r,rect.fill.g,rect.fill.b);
            setLineWidth(5);
            rectangle(x, y, w, h);
            fill();
        }
    }

    void visit(Image image) {
        writeln("TODO: drawing image: ", image.path);
        ImageSurface surface = ImageSurface.createFromPng(image.path);
        writeln("PRESENT LAYOUT: ", image.layoutLocation);

        // factor out
        int x, y, w, h;
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
            translate(x, y);
            scale(w / img_w, w / img_w);
            setSourceSurface(surface, 0, 0);
            paint();
            restore();
        }

    }

    void visit(Text text) {
        writeln("TODO: drawing text");

        int x, y, w, h;
        text.layoutLocation.match!(
            (BoundsLocation bl) {
            assert(false, "Text bounds location not implemented");
        },
            (CellLocation cl) {
            x = cl.col * colwidth + cl.dx;
            y = cl.row * rowheight + cl.dy;
            w = x + cl.colspan * colwidth;
            h = y + cl.rowspan * rowheight;
        });
        with (context) {
            setSourceRgb(0.0, 0.0, 1.0);
            textExtents(text.content, &extents);
            moveTo(x, y);
            showText(text.content);
        }

    }
}

void presentDeck(string[] args, Deck deck) {
    // writeln("Slide:  ", deck.slides[0].toString);
    // writeln("Master: ", deck.slides[0].master.toString);
    // writeln("DECK: ", deck.slides[0].master.items[0].visible);
    size_t currentSlide = 0;
    // open the gtk window

    Main.init(args);
    MainWindow projectorWin = new MainWindow("Projector",);
    projectorWin.setSizeRequest(960, 600);
    projectorWin.addOnDestroy((Widget w) { quitApp(); });

    bool onDraw(Scoped!Context context, Widget w) {

        GtkDrawingVisitor drawing = new GtkDrawingVisitor(context, w);
        drawing.showDebugOverlay = true;
        if (deck.slides.length == 0) {
            writeln("No slides to show");
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

    Keymap keymap;
    // Display myDisplay = Display.getDefault();
    // Seat seat = myDisplay.getDefaultSeat();
    // Device keyboard = seat.getKeyboard();
    keymap = Keymap.getDefault();

    bool onKeyPress(GdkEventKey* eventKey, Widget widget) {
        string pressedKey;
        int keys;

        pressedKey = keymap.keyvalName(eventKey.keyval);
        // writeln("The keyval is: ", eventKey.keyval, " which means the ", pressedKey, " was pressed.");

        size_t oldCurrentSlide = currentSlide;
        if (eventKey.keyval == GdkKeysyms.GDK_space || eventKey.keyval == GdkKeysyms.GDK_Right) {
            if (currentSlide < deck.slides.length - 1)
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
        if (oldCurrentSlide != currentSlide)
            projectorWin.queueDraw();

        return true;

    }

    bool onMousePress(Event event, Widget widget) {
        bool returnValue = false;

        if (event.type == EventType.BUTTON_PRESS) {
            GdkEventButton* mouseEvent = event.button;
            writeln("Mouse click: ", mouseEvent.button);
            returnValue = true;
        }

        return (returnValue);

    }

    projectorWin.addOnDraw(&onDraw);
    projectorWin.addOnKeyPress(&onKeyPress);
    projectorWin.addOnButtonPress(&onMousePress);

    projectorWin.showAll();
    Main.run();

}

void quitApp() {
    writeln("Quitting");
    Main.quit();
}
