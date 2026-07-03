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
import gtk.box;
import gtk.button;
import gtk.css_provider;
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
import signals;
import slides;
import types;

import sharedvars;

enum WIDTH = 1280;
enum HEIGHT = 720;

// convenience structs

class SlidexApplication : gtk.application.Application {
    ProjectionWindow projectionWindow;
    PresenterWindow presenterWindow;

    Deck deck;
    Config config;

    SharedVariables vartable = new SharedVariables();
    PresentationController presentationController;

    this(Deck deck, Config config) {
        super("com.slidex.projectionView", ApplicationFlags.DefaultFlags);

        this.deck = deck;
        this.config = config;

        // add "end-of-presentation" slide

        connectActivate(&onActivate);
    }

    void onActivate() {

        CssProvider cssProvider = new CssProvider();

        cssProvider.loadFromString("* { background:black; color:white; }");

        StyleContext.addProviderForDisplay(Display.getDefault(), cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (!projectionWindow) {
            projectionWindow = new ProjectionWindow(deck, vartable);
            projectionWindow.debug_ = config.debug_;
            addWindow(projectionWindow);
        }

        if (!presenterWindow) {
            presenterWindow = new PresenterWindow(vartable, deck.rootpath);
            addWindow(presenterWindow);
        }

        // Setup presentation controller
        presentationController = new PresentationController(deck, vartable);
        presentationController.onSlideChanged.connect((Slide s) {
            projectionWindow.setSlide(s);
            presenterWindow.setSlide(s);
        });
        presentationController.onLastSlide.connect(() {
            projectionWindow.setSlide(null);
            presenterWindow.setSlide(null);
        });
        presentationController.onStepChanged.connect((ulong step) {
            projectionWindow.setStep(step);
        });

        projectionWindow.present();
        presenterWindow.present();

        projectionWindow.setController(presentationController);

        presentationController.showSlide(config.slidenum);
    }
}

class ProjectionWindow : Window {
    bool isDebugMode;
    bool isFullScreen = false;
    bool isBlanking = false;

    PresentationController presentationController;

    SlideView slideView;
    Deck deck;

    this(Deck deck, SharedVariables vartable) {
        super();

        setTitle("Projection view");
        setDefaultSize(WIDTH, HEIGHT);

        // Create main UI slideview components
        Overlay overlay = new Overlay();
        overlay.setSizeRequest(WIDTH, HEIGHT);
        child = overlay;

        slideView = new SlideView(overlay, vartable, deck.rootpath);
        slideView.debug_ = isDebugMode;

        GestureClick clicked = new GestureClick();
        clicked.connectPressed(&onMousePress);
        slideView.addController(clicked);

        overlay.child = slideView;

        EventControllerKey keyController = new EventControllerKey();
        keyController.connectKeyPressed(&onKeyPress);
        addController(keyController);

        EventControllerMotion motionController = new EventControllerMotion();
        motionController.connectMotion(&onMotion);
        addController(motionController);

    }

    @property
    void debug_(bool debug_) {
        isDebugMode = debug_;
    }

    void setSlide(Slide slide) {
        slideView.setSlide(slide);
    }

    void setStep(ulong step) {
        slideView.setStep(step);
    }

    void setController(PresentationController presentationController) {
        this.presentationController = presentationController;
    }

private:
    ///////////////////
    // Event handlers
    //
    void onMousePress(int nPress, double x, double y, GestureClick gestureClick) {
        if (gestureClick.getButton() == 1) {
            if (x < slideView.getSize().w * 0.2)
                presentationController.advance();
            else
                presentationController.reverse();
        }

    }

    void onMotion(double x, double y, EventControllerMotion controller) {
        slideView.onMotion(x, y, controller);
    }

    bool onKeyPress(uint keyval, uint keycode, ModifierType state, EventControllerKey eventControllerKey) {

        // pressedKey = keymap.keyvalName(keyval);
        // writeln("The keyval is: ", keyval, " which means the ", keycode, " was pressed.");

        if (keyval == KEY_space || keyval == KEY_Right || keyval == KEY_Next) {
            presentationController.advance();
        }
        else if (keyval == KEY_Left || keyval == KEY_Prior) {
            presentationController.reverse();
        }
        else if (keyval == KEY_Escape) {
            if (isFullScreen) {
                // TODO: move into function
                unfullscreen();
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
                fullscreen();
                isFullScreen = true;
            }
            else {
                unfullscreen();
                isFullScreen = false;
            }
        }

        return true;

    }
}

class PresenterWindow : Window {

    Box boxRoot;
    Box boxLeft;
    Box boxToolbar;

    Button btnReverse;
    Button btnAdvance;

    SlideView slideView;

    SharedVariables vartable;

    this(SharedVariables vartable, string rootpath) {

        this.vartable = vartable;

        setTitle("Presenter view");
        setDefaultSize(WIDTH, HEIGHT);

        addCssClass("presenterwin");

        boxRoot = new Box(Orientation.Horizontal, 50);
        boxLeft = new Box(Orientation.Vertical, 30);
        boxToolbar = new Box(Orientation.Horizontal, 10);

        btnReverse = Button.newWithLabel("Previous");
        btnAdvance = Button.newWithLabel("Next");

        boxToolbar.append(btnReverse);
        boxToolbar.append(btnAdvance);

        slideView = new SlideView(new Overlay(), vartable, rootpath);

        boxLeft.append(slideView);
        boxLeft.append(boxToolbar);

        boxRoot.append(boxLeft);

        setChild(boxRoot);

    }

    void setSlide(Slide slide) {
        slideView.setSlide(slide);
    }
}

class PresentationController {

    size_t currentSlideIdx = 0;
    size_t currentStep = 0;

    SharedVariables vartable;

    Slide currentSlide;
    Deck deck;

    Signal!() onLastSlide;
    Signal!() onFirstSlide;
    Signal!(ulong) onStepChanged;
    Signal!(Slide) onSlideChanged;

    this(Deck deck, SharedVariables vartable) {

        this.vartable = vartable;

        this.deck = deck;

        updateSlideView(currentSlideIdx);
    }

    void showSlide(uint slidenum) {
        if (slidenum < 0 || slidenum > deck.slides.length)
            return;

        currentSlideIdx = slidenum;

        updateSlideView(currentSlideIdx);
    }

    void advance() {
        if (currentStep + 1 < currentSlide.events.length) {
            onStepChanged.emit(++currentStep);
        }
        else if (currentSlideIdx + 1 < deck.slides.length) {
            updateSlideView(++currentSlideIdx);
        }
        else if (currentSlideIdx + 1 == deck.slides.length) {
            onLastSlide.emit();
            writeln("Reached last slide");
        }
    }

    void reverse() {
        if (currentStep > 0) {
            onStepChanged.emit(--currentStep);
        }
        else if (currentSlideIdx > 0) {
            updateSlideView(--currentSlideIdx);
        }
        else {
            // TODO: only when verbose
            writeln("Reached first slide");
        }
    }

private:

    void updateSlideView(ulong slidenum) {
        if (slidenum >= deck.slides.length) {
            writeln("ERROR: setting slide index can't be larger than number of slides");
            return;
        }
        vartable["total"] = deck.slides.length;
        vartable["slide"] = currentSlideIdx + 1;
        currentSlide = deck.slides[slidenum];
        onSlideChanged.emit(currentSlide);
    }

}

class SlideView : DrawingArea {

    Slide slide;

    Slide endOfPresentationSlide;

    Variant[string][Slide] states;
    string rootpath;

    @property
    void debug_(bool debug_) {
        isDebugMode = debug_;
    }

    this(Overlay overlay, SharedVariables vartable, string rootpath) {

        this.overlay = overlay;
        this.vartable = vartable;
        this.rootpath = rootpath;

        setDrawFunc(&onDraw);

        endOfPresentationSlide = new Slide("EndOfPresentation-128721");
        Master master = new Master("EndOfPresMaster-121564234", IntOrLength(1), IntOrLength(1));
        master.background = RgbColour.Black;
        Text text = new Text("text-549839", new RichText("End of presentation".split(' ')
                .map!(w => TextItem(Word(w))).array), RgbColour.White, 10);
        text.layoutLocation = CellLocation(0, 0, 1, 1, 0, 0, 0, CellAlignment.BottomCenter);
        endOfPresentationSlide.items ~= text;
        endOfPresentationSlide.itemsMap[text.name] = text;
        endOfPresentationSlide.master = master;

        connectResize(&onSizeAllocate);

        setSizeRequest(WIDTH, HEIGHT);

    }

    void setSlide(Slide slide) {
        this.slide = slide;

        queueDraw();

    }

    void setStep(ulong step) {
        if (step < 0 || step >= slide.events.length) {
            stderr.writeln("ERROR: illegal step");
            return;
        }

        resetState();
        for (ulong i; i < step; i++) {
            slides.Event event = slide.events[i];
            evaluateFunction(event.func);

        }
        queueDraw();
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

    void resetState() {
    }

private:

    void onDraw(DrawingArea drawingArea, Context context, int width, int height) {

        if (isVideo)
            return;

        Slide activeSlide = slide;

        if (activeSlide is null) {
            activeSlide = endOfPresentationSlide;
        }

        if (isBlanking && slide !is null) {
            writeln("blanking");
            context.setSourceRgb(0, 0, 0);
            context.paint();
            return;
        }

        // TODO: do not create on each draw.
        GtkDrawingVisitor drawing = new GtkDrawingVisitor(context, Size(width, height), vartable, rootpath);
        drawing.showDebugOverlay = isDebugMode;

        drawing.factor = factor;

        activeSlide.master.accept(drawing);
        activeSlide.accept(drawing);

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

    bool isDebugMode = false;
    float factor = 1.0;
    bool isBlanking = false;
    SharedVariables vartable;

    Overlay overlay;
    Size size;
    Point mousePos;
}
