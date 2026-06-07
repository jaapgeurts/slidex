module presenter;

import std.algorithm.iteration;
import std.array;
import std.conv;
import std.format;
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
import gtk.event_controller_motion;
import gtk.gesture_click;

import gobject.value;

import gdk.c.types;
import gdk.event;
import gdk.types;

import common;
import rendering;
import slides;
import types;

enum WIDTH = 1280;
enum HEIGHT = 720;

// convenience structs

class SlidexApplication : gtk.application.Application {
    SlidexWindow window;
    Deck deck;
    Config config;

    this(Deck deck, Config config) {
        super("com.slidex.presenter", ApplicationFlags.DefaultFlags);

        this.deck = deck;
        this.config = config;

        connectActivate(&onActivate);
    }

    void onActivate() {
        if (!window) {
            window = new SlidexWindow(deck);
            window.debug_ = config.debug_;
            window.showSlide(config.slidenum);
            addWindow(window);
        }

        window.present();
    }
}

class SlidexWindow : Window {
    Presenter presenter;
    Deck deck;

    void debug_(bool debug_) {
        presenter.debug_ = debug_;
    }

    void showSlide(uint slidenum) {
        presenter.showSlide(slidenum);
    }

    this(Deck deck) {
        super();

        setTitle("Projector");
        setDefaultSize(WIDTH, HEIGHT);

        Overlay overlay = new Overlay();
        overlay.setSizeRequest(WIDTH, HEIGHT);
        child = overlay;

        presenter = new Presenter(overlay, deck);
        presenter.setSizeRequest(WIDTH, HEIGHT);
        presenter.onFullsceen = (widget) { fullscreen(); };
        presenter.onUnFullsceen = (widget) { unfullscreen(); };

        overlay.child = presenter;

        EventControllerKey keyController = new EventControllerKey();
        keyController.connectKeyPressed(&presenter.onKeyPress);
        addController(keyController);

        EventControllerMotion motionController = new EventControllerMotion();
        motionController.connectMotion(&presenter.onMotion);
        addController(motionController);

    }
}

class Presenter : DrawingArea {

    void delegate(Widget w) onFullsceen;
    void delegate(Widget w) onUnFullsceen;

    @property
    void debug_(bool debug_) {
        isDebugMode = debug_;
    }

    this(Overlay overlay, Deck deck) {

        this.overlay = overlay;
        this.deck = deck;

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

    void showSlide(uint slidenum) {
        if (slidenum < 0 || slidenum > deck.slides.length)
            return;

        currentSlide = slidenum;

        updateSlideView();
    }

    void nextSlide() {
        if (currentSlide < deck.slides.length) {
            currentSlide++;
            updateSlideView();
        }
        else {
            // TODO: only when verbose
            writeln("Reached last slide");
        }
    }

    void previousSlide() {
        if (currentSlide > 0) {
            currentSlide--;
            updateSlideView();
        }
        else {
            // TODO: only when verbose
            writeln("Reached first slide");
        }
    }

private:

    void updateSlideView() {
        vartable["slide"] = currentSlide + 1;
        firePrepareSlideForVideo();
        queueDraw();
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
        GtkDrawingVisitor drawing = new GtkDrawingVisitor(context, Size(width, height), vartable, deck
                .rootpath);
        drawing.showDebugOverlay = isDebugMode;

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

            if (isDebugMode) {
                uint c;
                float sum = 0;
                writeln(drawing.colsizes);
                // TODO wrong because of factor.
                for (c = 0; c < drawing.colsizes.length; ++c) {
                    sum += drawing.colsizes[c];
                    if (mousePos.x <= sum)
                        break;
                }
                c++;
                uint r;
                sum = 0;
                for (r = 0; r < drawing.rowsizes.length; ++r) {
                    sum += drawing.rowsizes[r];
                    if (mousePos.y <= sum)
                        break;
                }
                r++;
                TextExtents extent1;
                TextExtents extent2;
                string line1 = format("x,y: %d,%d", cast(int) mousePos.x, cast(int) mousePos.y);
                string line2 = format("c,r: %d,%d", c, r);
                with (context) {
                    setSourceRgb(0.7, 0.7, 0.7);
                    textExtents(line1, extent1);
                    textExtents(line2, extent2);
                    float twidth = extent1.width > extent2.width ? extent1.width : extent2.width;
                    rectangle(mousePos.x, mousePos.y + 30, twidth + 30, extent1.height * 3);
                    fill();
                    setSourceRgb(0.0, 0.0, 0.9);
                    // context.setFontFace("");
                    context.setFontSize(16);
                    moveTo(mousePos.x + 2, mousePos.y + 30 + 12);
                    showText(line1);
                    moveTo(mousePos.x + 2, mousePos.y + 30 + 26);
                    showText(line2);
                }
            }
        }
    }

    bool onKeyPress(uint keyval, uint keycode, ModifierType state, EventControllerKey eventControllerKey) {

        // pressedKey = keymap.keyvalName(keyval);
        writeln("The keyval is: ", keyval, " which means the ", keycode, " was pressed.");

        if (keyval == KEY_space || keyval == KEY_Right || keyval == KEY_Next) {
            nextSlide();
        }
        else if (keyval == KEY_Left || keyval == KEY_Prior) {
            previousSlide();
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

        return true;

    }

    void onMotion(double x, double y, EventControllerMotion eventControllerMotion) {
        writeln(i"x: $(x), y: $(y)");
        mousePos = Point(x, y);
        queueDraw();
    }

    void firePrepareSlideForVideo() {

        VideoPreparationVisitor prepvideo = new VideoPreparationVisitor(overlay);

        if (deck.slides.length == 0 || currentSlide == deck.slides.length) {
            writeln("No slides to show or 'end of presentation'.");
        }
        else {
            Slide slide = deck.slides[currentSlide];
            slide.master.accept(prepvideo);
            slide.accept(prepvideo);
        }
    }

    void onMousePress(int nPress, double x, double y, GestureClick gestureClick) {
        if (gestureClick.getButton() == 1) {
            if (x < size.w * 0.2)
                previousSlide();
            else
                nextSlide();
        }

    }

    void onSizeAllocate(int width, int height, DrawingArea drawingArea) {

        size = Size(width, height);
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
            moveTo((size.w - extents.width) / 2, size.h - 20);
            setSourceRgb(1, 1, 1);
            showText(endMessage);
        }
    }

    Deck deck;

    size_t currentSlide = 0;
    bool isFullScreen = false;
    bool isBlanking = false;
    bool isDebugMode = false;
    float factor = 1.0;

    Variant[string] vartable;

    Overlay overlay;
    Size size;
    Point mousePos;
}
