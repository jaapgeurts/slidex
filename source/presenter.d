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
import gtk.event_controller_key;
import gtk.gesture_click;

import gobject.value;

import gdk.c.types;
import gdk.event;
import gdk.types;

import rendering;

import slides;

enum WIDTH = 1280;
enum HEIGHT = 720;

class SlidexWindow : Window {
    Deck deck;

    this(Deck deck, bool debug_) {
        super();

        setTitle("Projector");
        setDefaultSize(WIDTH, HEIGHT);

        Overlay overlay = new Overlay();
        overlay.setSizeRequest(WIDTH, HEIGHT);
        child = overlay;

        Presenter presenter = new Presenter(overlay, deck, debug_);
        presenter.setSizeRequest(WIDTH, HEIGHT);
        presenter.onFullsceen = (widget) { fullscreen(); };
        presenter.onUnFullsceen = (widget) { unfullscreen(); };

        overlay.child = presenter;
        EventControllerKey eventController = new EventControllerKey();
        eventController.connectKeyPressed(&presenter.onKeyPress);
        addController(eventController);
    }
}

class SlidexApplication : gtk.application.Application {
    SlidexWindow window;
    Deck deck;
    bool debug_;

    this(Deck deck, bool debug_) {
        super("com.slidex.presenter", ApplicationFlags.DefaultFlags);

        this.deck = deck;
        this.debug_ = debug_;

        connectActivate(&onActivate);
    }

    void onActivate() {
        if (!window) {
            window = new SlidexWindow(deck, debug_);
            addWindow(window);
        }

        window.present();
    }
}

void presentDeck(string[] args, Deck deck) {
    // writeln("Slide:  ", deck.slides[0].toString);
    // writeln("Master: ", deck.slides[0].master.toString);
    // writeln("DECK: ", deck.slides[0].master.items[0].visible);
    // open the gtk window
    bool debug_ = args.length > 2 && args[2] == "debug";
    SlidexApplication app = new SlidexApplication(deck, debug_);
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

    void delegate(Widget w) onFullsceen;
    void delegate(Widget w) onUnFullsceen;

    Deck deck;

    this(Overlay overlay, Deck deck, bool debug_) {

        this.overlay = overlay;
        this.deck = deck;

        isDebugOverlay = debug_;

        setDrawFunc(&onDraw);

        // enable click events.
        // TODO: remove
        // addEvents(GdkEventMask.ButtonPressMask);

        GestureClick clicked = new GestureClick();
        clicked.connectPressed(&onMousePress);
        addController(clicked);

        connectResize(&onSizeAllocate);

        // projectorWin.getRootWindow().flush();
        // Display myDisplay = Display.getDefault();
        // Seat seat = myDisplay.getDefaultSeat();
        // Device keyboard = seat.getKeyboard();
        // keymap = Keymap.getDefault();

        vartable["total"] = deck.slides.length;
        vartable["slide"] = currentSlide + 1;

    }

    void onDraw(DrawingArea drawingArea, Context context, int width, int height) {

        if (isVideo)
            return;

        if (isBlanking) {
            writeln("blanking");
            context.setSourceRgb(0, 0, 0);
            context.paint();
            return;
        }
        GtkDrawingVisitor drawing = new GtkDrawingVisitor(context, Allocation(0, 0, width, height), vartable, deck.rootpath);
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
    }

    bool onKeyPress(uint keyval, uint keycode, ModifierType state, EventControllerKey eventControllerKey) {

        // pressedKey = keymap.keyvalName(keyval);
        writeln("The keyval is: ", keyval, " which means the ", keycode, " was pressed.");

        size_t oldCurrentSlide = currentSlide;
        if (keyval == KEY_space || keyval == KEY_Right || keyval == KEY_Next) {
            if (currentSlide < deck.slides.length)
                currentSlide++;
            else
                writeln("Reached last slide");
        }
        else if (keyval == KEY_Left || keyval == KEY_Prior) {
            if (currentSlide > 0)
                currentSlide--;
            else
                writeln("Reached first slide");
        }
        else if (keyval == KEY_Escape) {
            if (isFullScreen) {
                // TODO: move into function
                if (onUnFullsceen !is null)
                    onUnFullsceen(this);
                isFullScreen = false;
            }
        }
        else if (keyval == KEY_b || keyval == KEY_B) {
            if (isFullScreen) {
                // TODO: move into function
                isBlanking = !isBlanking;
                queueDraw();
            }
        }
        else if (keyval == KEY_F11) {
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

    void onMousePress(int nPress, double x, double y, GestureClick gestureClick) {

        writeln("Mouse click: ", gestureClick.getCurrentButton());

    }

    void onSizeAllocate(int width, int height, DrawingArea drawingArea) {

        size = Allocation(0,0,width, height);
        factor = width / 920.0;
    }

    void drawEndOfPresentation(Context context) {
        TextExtents extents;
        // Set background to black
        with (context) {
            setSourceRgb(0, 0, 0);
            paint();
            string endMessage = "End of presentation";
            textExtents(endMessage, extents);
            // writeln("pos: x:", (size.width - extents.width) / 2, "y: ", size.height - 20);
            moveTo((size.width - extents.width) / 2, size.height - 20);
            setSourceRgb(1, 1, 1);
            showText(endMessage);
        }
    }

}
