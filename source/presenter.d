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

import gio.types : ApplicationFlags;
import gio.application;

import gtk.application;
import gtk.application_window;
import gtk.drawing_area;
import gtk.event_controller;
import gtk.overlay;
import gtk.types;
import gtk.widget;

// import gobject.Value;

// import gdk.event;
// import gdk.keymap;
// import gdk.keysyms;

import rendering;

import slides;
import core.sys.posix.sys.socket;
import gtk.gesture_click;

class PresenterWindow : ApplicationWindow {
    this(gtk.application.Application app) {
        super(app);
        setTitle("Main Window");
        setDefaultSize(600, 800);
        setShowMenubar = true;
    }
}

class SlidexApplication : gtk.application.Application {

    PresenterWindow presenter;
    Deck deck;

    this(Deck deck) {
        super("personal.slidex", ApplicationFlags.DefaultFlags);

        this.deck = deck;

        connectActivate(&onActivate);

        // connectStartup(&onstartUp
        // GStreamer.init(args);

        // Overlay overlay = new Overlay();
        // projectorWin.add(overlay);

        // Presenter presenter = new Presenter(overlay, deck, args);
        // presenter.setSizeRequest(960, 600);
        // presenter.onFullsceen = (widget) { projectorWin.fullscreen(); };
        // presenter.onUnFullsceen = (widget) { projectorWin.unfullscreen(); };

        // overlay.add(presenter);

        // projectorWin.addOnDestroy((Widget w) { writeln("Quitting"); Main.quit(); });
        // projectorWin.addOnKeyPress(&presenter.onKeyPress);

        // projectorWin.showAll();

    }

    void onActivate() {
        if (!presenter)
            presenter = new PresenterWindow(this);
        presenter.present();

    }
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
    // Keymap keymap;

    void delegate(Widget w) onFullsceen;
    void delegate(Widget w) onUnFullsceen;

    Deck deck;

    this(Overlay overlay, Deck deck, string[] args) {

        this.overlay = overlay;
        this.deck = deck;
        isDebugOverlay = args.length > 2 && args[2] == "debug";

        setDrawFunc(&onDraw);

        GestureClick clicked = new GestureClick();
        clicked.connectPressed((int nPress, double x, double y, GestureClick gestureClick) {
            writeln("Clicked"); 
            assert(false,"mouse clicks not handled");
            // onMousePress()
        });
        addController(clicked);

        connectResize((int width, int height, DrawingArea drawingArea) {
            writeln("resized");
            assert(false,"resize not handled");
        // addOnSizeAllocate(&onSizeAllocate);
            });

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
            context.setSourceRgb(0, 0, 0);
            context.paint();
            return;
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
        return;
    }

    // bool onKeyPress() { // (EventKey* eventKey, Widget widget) {
    //     string pressedKey;
    //     int keys;

    //     // pressedKey = keymap.keyvalName(eventKey.keyval);
    //     // writeln("The keyval is: ", eventKey.keyval, " which means the ", pressedKey, " was pressed.");

    //     size_t oldCurrentSlide = currentSlide;
    //     if (eventKey.keyval == GdkKeysyms.GDK_space || eventKey.keyval == GdkKeysyms.GDK_Right) {
    //         if (currentSlide < deck.slides.length)
    //             currentSlide++;
    //         else
    //             writeln("Reached last slide");
    //     }
    //     else if (eventKey.keyval == GdkKeysyms.GDK_Left) {
    //         if (currentSlide > 0)
    //             currentSlide--;
    //         else
    //             writeln("Reached first slide");
    //     }
    //     else if (eventKey.keyval == GdkKeysyms.GDK_Escape) {
    //         if (isFullScreen) {
    //             // TODO: move into function
    //             if (onUnFullsceen !is null)
    //                 onUnFullsceen(this);
    //             isFullScreen = false;
    //         }
    //         else {
    //             Main.quit();
    //         }
    //     }
    //     else if (eventKey.keyval == GdkKeysyms.GDK_b) {
    //         if (isFullScreen) {
    //             // TODO: move into function
    //             isBlanking = !isBlanking;
    //             queueDraw();
    //         }
    //     }
    //     else if (eventKey.keyval == GdkKeysyms.GDK_F11) {
    //         if (!isFullScreen) {
    //             // TODO: move into function
    //             isBlanking = false;
    //             if (onFullsceen !is null)
    //                 onFullsceen(this);
    //             isFullScreen = true;
    //         }
    //         else {
    //             if (onUnFullsceen !is null)
    //                 onUnFullsceen(this);
    //             isFullScreen = false;
    //         }
    //     }

    //     if (oldCurrentSlide != currentSlide) {
    //         vartable["slide"] = currentSlide + 1;
    //         // TODO: move next line away from here.
    //         firePrepareSlideForVideo();
    //         queueDraw();
    //     }

    //     return true;

    // }

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

    // bool onMousePress() { //(Event event, Widget widget) {
    //     bool returnValue = false;

    //     if (event.type == gdk.Event.EventType.BUTTON_PRESS) {
    //         GdkEventButton* mouseEvent = event.button;
    //         writeln("Mouse click: ", mouseEvent.button);
    //         returnValue = true;
    //     }

    //     return (returnValue);

    // }

    void onSizeAllocate(Allocation newSize, Widget) {

        size = newSize;
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
