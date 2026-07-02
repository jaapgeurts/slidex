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
import gtk.event_controller_key;
import gtk.event_controller_motion;
import gtk.gesture_click;
import gtk.global;
import gtk.overlay;
import gtk.style_context;
import gtk.types;
import gtk.widget;
import gtk.window;

import gobject.value;

import gdk.c.types;
import gdk.display;
import gdk.event;
import gdk.types;

import common;
import rendering;
import slides;
import types;
import gtk.css_provider;

import sharedvars;

enum WIDTH = 1280;
enum HEIGHT = 720;

// convenience structs

class SlidexApplication : gtk.application.Application {
    ProjectionWindow projectionWindow;
    PresenterWindow presenterWindow;

    Deck deck;
    Config config;

    this(Deck deck, Config config) {
        super("com.slidex.projectionView", ApplicationFlags.DefaultFlags);

        this.deck = deck;
        this.config = config;

        connectActivate(&onActivate);
    }

    void onActivate() {

        CssProvider cssProvider = new CssProvider();

        cssProvider.loadFromString("* { background:black; }");

        StyleContext.addProviderForDisplay(Display.getDefault(), cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (!projectionWindow) {
            projectionWindow = new ProjectionWindow(deck);
            projectionWindow.debug_ = config.debug_;
            projectionWindow.showSlide(config.slidenum);
            addWindow(projectionWindow);
        }

        projectionWindow.present();

        if (!presenterWindow) {
            presenterWindow = new PresenterWindow();
            addWindow(presenterWindow);
        }

        presenterWindow.present();
    }
}

class ProjectionWindow : Window {
    ProjectionView projectionView;
    Deck deck;

    void debug_(bool debug_) {
        projectionView.debug_ = debug_;
    }

    void showSlide(uint slidenum) {
        projectionView.showSlide(slidenum);
    }

    this(Deck deck) {
        super();

        setTitle("Projection view");
        setDefaultSize(WIDTH, HEIGHT);

        Overlay overlay = new Overlay();
        overlay.setSizeRequest(WIDTH, HEIGHT);
        child = overlay;

        projectionView = new ProjectionView(overlay, deck);
        projectionView.onFullsceen = () { fullscreen(); };
        projectionView.onUnFullsceen = () { unfullscreen(); };

        overlay.child = projectionView.widget();

        EventControllerKey keyController = new EventControllerKey();
        keyController.connectKeyPressed(&projectionView.onKeyPress);
        addController(keyController);

        EventControllerMotion motionController = new EventControllerMotion();
        motionController.connectMotion(&projectionView.onMotion);
        addController(motionController);

    }
}

class PresenterWindow : Window {
    SlideView slideView;

    this() {

        setTitle("Presenter view");
        setDefaultSize(WIDTH, HEIGHT);

        addCssClass("presenterwin");

    }
}

class ProjectionView {

    bool isDebugMode;
    bool isFullScreen = false;
    bool isBlanking = false;
    size_t currentSlideIdx = 0;

    void delegate() onFullsceen;
    void delegate() onUnFullsceen;

    SharedVariables vartable;

    SlideView slideView;
    Slide currentSlide;

    Deck deck;

    @property
    void debug_(bool debug_) {
        isDebugMode = debug_;
    }

    this(Overlay overlay, Deck deck) {

        vartable = new SharedVariables();

        slideView = new SlideView(overlay, deck.rootpath);
        this.deck = deck;

        GestureClick clicked = new GestureClick();
        clicked.connectPressed(&onMousePress);
        slideView.addController(clicked);
        
        updateSlideView(currentSlideIdx);
    }

    Widget widget() {
        return slideView;
    }

    void showSlide(uint slidenum) {
        if (slidenum < 0 || slidenum > deck.slides.length)
            return;

        currentSlideIdx = slidenum;

        updateSlideView(currentSlideIdx);
    }

    void advance() {
        if (slideView.hasMoreSteps()) {
            slideView.advanceStep();
        }
        else if (currentSlideIdx < deck.slides.length) {
            // TODO: do not print black when the current slide is outside the bounds.
            currentSlideIdx++;
            updateSlideView(currentSlideIdx);
        }
        else {
            writeln("Reached last slide");
        }
    }

    void reverse() {
        if (currentSlideIdx > 0) {
            currentSlideIdx--;
            updateSlideView(currentSlideIdx);
        }
        else {
            // TODO: only when verbose
            writeln("Reached first slide");
        }
    }

    ///////////////////
    // Event handlers
    //
    void onMousePress(int nPress, double x, double y, GestureClick gestureClick) {
        if (gestureClick.getButton() == 1) {
            if (x < slideView.getSize().w * 0.2)
                advance();
            else
                reverse();
        }

    }

    void onMotion(double x, double y, EventControllerMotion controller) {
        slideView.onMotion(x, y, controller);
    }

private:

    void updateSlideView(ulong slidenum) {
        vartable["slide"] = currentSlideIdx + 1;
        currentSlide = deck.slides[slidenum];
        slideView.setSlide(currentSlide);
    }

    bool onKeyPress(uint keyval, uint keycode, ModifierType state, EventControllerKey eventControllerKey) {

        // pressedKey = keymap.keyvalName(keyval);
        // writeln("The keyval is: ", keyval, " which means the ", keycode, " was pressed.");

        if (keyval == KEY_space || keyval == KEY_Right || keyval == KEY_Next) {
            advance();
        }
        else if (keyval == KEY_Left || keyval == KEY_Prior) {
            reverse();
        }
        else if (keyval == KEY_Escape) {
            if (isFullScreen) {
                // TODO: move into function
                if (onUnFullsceen !is null)
                    onUnFullsceen();
                isFullScreen = false;
            }
        }
        else if (keyval == KEY_b || keyval == KEY_B) {
            if (isFullScreen) {
                isBlanking = !isBlanking;
                slideView.setBlanking(isBlanking);
            }
        }
        else if (keyval == KEY_F11) {
            isBlanking = false;
            slideView.setBlanking(isBlanking);
            if (!isFullScreen) {
                if (onFullsceen !is null)
                    onFullsceen();
                isFullScreen = true;
            }
            else {
                if (onUnFullsceen !is null)
                    onUnFullsceen();
                isFullScreen = false;
            }
        }

        return true;

    }
}

class SlideView : DrawingArea {

    Slide slide;

    Variant[string][Slide] states;
    string rootpath;

    @property
    void debug_(bool debug_) {
        isDebugMode = debug_;
    }

    this(Overlay overlay, string rootpath) {

        this.overlay = overlay;
        this.rootpath = rootpath;

        setDrawFunc(&onDraw);

        // enable click events.
        // TODO: remove
        // addEvents(GdkEventMask.ButtonPressMask);

        connectResize(&onSizeAllocate);

        // projectorWin.getRootWindow().flush();
        // Display myDisplay = Display.getDefault();
        // Seat seat = myDisplay.getDefaultSeat();
        // Device keyboard = seat.getKeyboard();
        // keymap = Keymap.getDefault();

        setSizeRequest(WIDTH, HEIGHT);

    }

    void setSlide(Slide slide) {
        this.slide = slide;

        queueDraw();

    }

    bool hasMoreSteps() {
        return currentEvent + 1 < slide.events.length;
    }

    void advanceStep() {
        if (currentEvent + 1 < slide.events.length) {
            currentEvent++;
            slides.Event event = slide.events[currentEvent];
            evaluateFunction(event.func);

        }
    }

    void reverseStep() {
        writeln("reverseStep(): Not implemented yet");
    }

    void setBlanking(bool isBlank) {
        this.isBlanking = isBlank;
    }

    void onMotion(double x, double y, EventControllerMotion eventControllerMotion) {
        // writeln(i"x: $(x), y: $(y)");
        mousePos = Point(x, y);
        queueDraw();
    }

    Size getSize() {
        return size;
    }

private:

    void onDraw(DrawingArea drawingArea, Context context, int width, int height) {

        if (isVideo)
            return;

        if (isBlanking) {
            writeln("blanking");
            context.setSourceRgb(0, 0, 0);
            context.paint();
            return;
        }
        // TODO: do not create on each draw.
        GtkDrawingVisitor drawing = new GtkDrawingVisitor(context, Size(width, height), vartable, rootpath);
        drawing.showDebugOverlay = isDebugMode;

        drawing.factor = factor;

        slide.master.accept(drawing);
        slide.accept(drawing);

        if (isDebugMode) {
            uint c, r;
            // Draw point & cell location info
            drawing.mapPointToCell(mousePos, c, r);
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

    void firePrepareSlideForVideo() {

        VideoPreparationVisitor prepvideo = new VideoPreparationVisitor(overlay);

        if (slide is null) {
            writeln("No slides to show or 'end of presentation'.");
        }
        else {
            slide.master.accept(prepvideo);
            slide.accept(prepvideo);
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

    void evaluateFunction(Function func) {
        if (func.name == "reveal") {
            foreach (arg; func.positionalargs) {
                // TODO: we should validate the type of the argument here.
                // it seems the type is string, but it should be a Value
                writeln("reveal: ", arg);
                if (auto item = arg.get!string in slide.itemsMap)
                    item.visible = true;
            }
        }
    }

    size_t currentEvent = 0;
    bool isDebugMode = false;
    float factor = 1.0;
    bool isBlanking = false;
    SharedVariables vartable;

    Overlay overlay;
    Size size;
    Point mousePos;
}
