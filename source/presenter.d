module presenter;

import std.algorithm.iteration;
import std.array;
import std.conv;
import std.stdio;
import std.sumtype;
import std.typecons;
import std.variant;

import core.stdc.ctype;

import cairo.context;
import cairo.types;

import gio.types;

import gtk.application;
import gtk.application_window;
import gtk.drawing_area;
import gtk.overlay;
import gtk.widget;
import gtk.types;
import gtk.window;
import gtk.global;

import gobject.value;

import gdk.c.types;
import gdk.event;
import gdk.event_button;
import gdk.event_key;
import gdk.keymap;
import gdk.types;

import rendering;

import slides;

class SlidexWindow : Window {
    Deck deck;

    this(Deck deck) {
        super(gtk.types.WindowType.Toplevel);

        setTitle("Projector");
        setDefaultSize(960, 600);

        Overlay overlay = new Overlay();
        add(overlay);

        Presenter presenter = new Presenter(overlay, deck);
        presenter.setSizeRequest(960, 600);
        presenter.onFullsceen = (widget) { fullscreen(); };
        presenter.onUnFullsceen = (widget) { unfullscreen(); };

        overlay.add(presenter);
        connectKeyPressEvent(&presenter.onKeyPress, No.After);

        // connectKeyPressEvent((EventKey eventKey, Widget widget) {
        //     writeln("Eventkey: ", eventKey);
        //     writeln("Widget:  ", widget);
        //     return true;
        // });
    }
}

class SlidexApplication : gtk.application.Application {
    SlidexWindow window;
    Deck deck;

    this(Deck deck) {
        super("com.slidex.presenter", ApplicationFlags.DefaultFlags);

        this.deck = deck;

        connectActivate(&onActivate);
    }

    void onActivate() {
        if (!window) {
            window = new SlidexWindow(deck);
            addWindow(window);
        }

        window.showAll();

    }
}

void presentDeck(string[] args, Deck deck) {
    // writeln("Slide:  ", deck.slides[0].toString);
    // writeln("Master: ", deck.slides[0].master.toString);
    // writeln("DECK: ", deck.slides[0].master.items[0].visible);
    // open the gtk window

    SlidexApplication app = new SlidexApplication(deck);
    app.run([args[0]]);

}

class Presenter : DrawingArea {
    size_t currentSlide = 0;
    bool isFullScreen = false;
    bool isBlanking = false;
    bool isDebugOverlay = false;
    float factor = 1.0;

    Variant[string] vartable;

    Overlay overlay;
    Allocation size;
    Keymap keymap;

    void delegate(Widget w) onFullsceen;
    void delegate(Widget w) onUnFullsceen;

    Deck deck;

    this(Overlay overlay, Deck deck) {

        this.overlay = overlay;
        this.deck = deck;

        // enable click events.
        addEvents(GdkEventMask.ButtonPressMask);

        connectDraw(&onDraw);
        connectButtonPressEvent(&onMousePress);
        connectSizeAllocate(&onSizeAllocate);

        // projectorWin.getRootWindow().flush();
        // Display myDisplay = Display.getDefault();
        // Seat seat = myDisplay.getDefaultSeat();
        // Device keyboard = seat.getKeyboard();
        keymap = Keymap.getDefault();

        vartable["total"] = deck.slides.length;
        vartable["slide"] = currentSlide + 1;

    }

    bool onDraw(Context context, Widget w) {

        if (isVideo)
            return true;

        if (isBlanking) {
            context.setSourceRgb(0, 0, 0);
            context.paint();
            return true;
        }
        GtkDrawingVisitor drawing = new GtkDrawingVisitor(context, w, vartable);
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

    bool onKeyPress(EventKey eventKey, Widget widget) {
        // string pressedKey;
        int keys;
        // TODO: why is eventkey null
        if (eventKey is null)
            return false;

        // pressedKey = keymap.keyvalName(eventKey.keyval);
        // writeln("The keyval is: ", eventKey.keyval, " which means the ", pressedKey, " was pressed.");

        size_t oldCurrentSlide = currentSlide;
        if (eventKey.keyval == KEY_space || eventKey.keyval == KEY_Right) {
            if (currentSlide < deck.slides.length)
                currentSlide++;
            else
                writeln("Reached last slide");
        }
        else if (eventKey.keyval == KEY_Left) {
            if (currentSlide > 0)
                currentSlide--;
            else
                writeln("Reached first slide");
        }
        else if (eventKey.keyval == KEY_Escape) {
            if (isFullScreen) {
                // TODO: move into function
                if (onUnFullsceen !is null)
                    onUnFullsceen(this);
                isFullScreen = false;
            }
            else {
                mainQuit();
            }
        }
        else if (eventKey.keyval == KEY_b) {
            if (isFullScreen) {
                // TODO: move into function
                isBlanking = !isBlanking;
                queueDraw();
            }
        }
        else if (eventKey.keyval == KEY_F11) {
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
            vartable["slide"] = currentSlide + 1;
            // TODO: move next line away from here.
            firePrepareSlideForVideo();
            queueDraw();
        }

        return true;

    }

    private void firePrepareSlideForVideo() {

        VideoPreparationVisitor prepvideo = new VideoPreparationVisitor(overlay);

        if (deck.slides.length == 0 || currentSlide == deck.slides.length) {
            writeln("No slides to show");
        }
        else {
            Slide slide = deck.slides[currentSlide];
            slide.master.accept(prepvideo);
            slide.accept(prepvideo);
        }
    }

    bool onMousePress(EventButton event, Widget widget) {
        bool returnValue = false;

        if (event.type == EventType.ButtonPress) {
            writeln("Mouse click: ", event.button);
            returnValue = true;
        }

        return (returnValue);

    }

    void onSizeAllocate(Allocation newSize, Widget) {

        size = newSize;
        factor = newSize.width / 920.0;
    }

    void drawEndOfPresentation(Context context) {
        TextExtents extents;
        // Set background to black
        with (context) {
            setSourceRgb(0, 0, 0);
            paint();
            string endMessage = "End of presentation";
            textExtents(endMessage, extents);
            moveTo(size.width / 2 - extents.width / 2, size.height - 20);
            setSourceRgb(1, 1, 1);
            showText(endMessage);
        }
    }

}
