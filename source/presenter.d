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
import gtk.image;
import gtk.label;
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

        cssProvider.loadFromString(`
            .projectorwin { background:black; color:white; }
            .presenterwin { background: #282828; }
            .framed { border: 1px solid white; }
            .speakernotes { color: white; }
            button.flat label  {
                color: #d7d7d7;
            }
            button.flat image {
                color: #d7d7d7;
            }
            button.flat {
                background: transparent;
                border: none;
                box-shadow: none;
                color: #d7d7d7;
            }

            button.flat:hover {
                background-color: rgba(255, 255, 255, 0.1);
            }

            button.flat:active,
            button.flat:checked {
                background-color: rgba(255, 255, 255, 0.3);
            }
        `);

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
        presentationController.onSlideChanged.connect((Slide s, size_t index) {
            projectionWindow.setSlide(s);
            presenterWindow.setCurrentSlide(s);
            presenterWindow.setNextSlide(index + 1 > 0 && index + 1 < deck.slides.length ? deck
                .slides[index + 1] : null);
        });
        presentationController.onLastSlide.connect(() {
            projectionWindow.setSlide(null);
            presenterWindow.setCurrentSlide(null);
        });
        presentationController.onAdvanceStep.connect((ulong step) {
            projectionWindow.advanceStep(step);
            presenterWindow.advanceStep(step);
        });
        presentationController.onReverseStep.connect((ulong step) {
            projectionWindow.reverseStep(step);
            presenterWindow.reverseStep(step);
        });

        projectionWindow.present();
        presenterWindow.present();

        projectionWindow.setController(presentationController);
        presenterWindow.setController(presentationController);

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

        addCssClass("projectorwin");

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
        slideView.debug_ = debug_;
    }

    void setSlide(Slide slide) {
        slideView.setSlide(slide);
    }

    void setController(PresentationController presentationController) {
        this.presentationController = presentationController;
    }

    void advanceStep(ulong step) {
        slideView.advanceStep(step);
    }

    void reverseStep(ulong step) {
        slideView.reverseStep(step);
    }

private:
    ///////////////////
    // Event handlers
    //
    void onMousePress(int nPress, double x, double y, GestureClick gestureClick) {
        if (gestureClick.getButton() == 1) {
            if (x < slideView.getSize().w * 0.2)
                presentationController.reverse();
            else
                presentationController.advance();
        }

    }

    void onMotion(double x, double y, EventControllerMotion controller) {
        slideView.onMotion(x, y, controller);
    }

    bool onKeyPress(uint keyval, uint keycode, ModifierType state, EventControllerKey eventControllerKey) {

        // pressedKey = keymap.keyvalName(keyval);
        // writeln("The keyval is: ", keyval, " which means the ", keycode, " was pressed.");

        switch (keyval) {

        case KEY_space:
        case KEY_Right:
        case KEY_Next: // // is equal to KEY_Page_Down
            presentationController.advance();
            break;
        case KEY_Left:
        case KEY_Prior: // is equal to KEY_Page_Up
            presentationController.reverse();
            break;
        case KEY_Home:
            assert(false, "TODO: Home key should send presentation back to first slide.");
            break;
        case KEY_End:
            assert(false, "TODO: Home key should send presentation back to last slide.");
            break;
        case KEY_Escape:
            if (isFullScreen) {
                // TODO: move into function
                unfullscreen();
                isFullScreen = false;
            }
            break;
        case KEY_b:
        case KEY_B:
            if (isFullScreen) {
                isBlanking = !isBlanking;
                slideView.setBlanking(isBlanking);
            }
            break;
        case KEY_F11:
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
            break;
        default:
            return false;
        }

        return true;

    }
}

class PresenterWindow : Window {

    Box boxRoot;
    Box boxLeft;
    Box boxRight;
    Box boxToolbar;

    Label lblNotes;

    Button btnReverse;
    Button btnAdvance;

    SlideView currentSlideView;
    SlideView nextSlideView;

    SharedVariables vartable;
    PresentationController presentationController;

    this(SharedVariables vartable, string rootpath) {

        this.vartable = vartable;

        setTitle("Presenter view");
        setDefaultSize(WIDTH, HEIGHT);

        addCssClass("presenterwin");

        boxRoot = new Box(Orientation.Horizontal, 50);
        boxRoot.setMarginTop(30);
        boxRoot.setMarginStart(30);
        boxRoot.setMarginBottom(30);
        boxRoot.setMarginEnd(30);

        boxLeft = new Box(Orientation.Vertical, 30);
        boxRight = new Box(Orientation.Vertical, 30);
        boxToolbar = new Box(Orientation.Horizontal, 10);

        // Box left

        // toolbar
        Box box = new Box(Orientation.Vertical, 10);
        gtk.image.Image img = gtk.image.Image.newFromIconName("arrow-left-symbolic");
        img.setPixelSize(48);
        box.append(img);
        box.append(new Label("Previous"));
        btnReverse = new Button();
        btnReverse.addCssClass("flat");
        btnReverse.setChild(box);
        btnReverse.connectClicked((Button b) { presentationController.reverse(); });

        box = new Box(Orientation.Vertical, 10);
        img = gtk.image.Image.newFromIconName("arrow-right-symbolic");
        img.setPixelSize(48);
        box.append(img);
        box.append(new Label("Next"));
        btnAdvance = new Button();
        btnAdvance.addCssClass("flat");
        btnAdvance.setChild(box);
        btnAdvance.connectClicked((Button b) { presentationController.advance(); });

        boxToolbar.append(btnReverse);
        boxToolbar.append(btnAdvance);

        currentSlideView = new SlideView(new Overlay(), vartable, rootpath);
        currentSlideView.setSizeRequest(WIDTH * 7 / 10, HEIGHT * 7 / 10);

        boxLeft.append(currentSlideView);
        boxLeft.append(boxToolbar);

        // Box right
        nextSlideView = new SlideView(new Overlay(), vartable, rootpath);
        nextSlideView.setSizeRequest(WIDTH / 2, HEIGHT / 2);

        boxRight.append(nextSlideView);

        lblNotes = new Label("NO - NOTES - SPECIFIED");
        lblNotes.addCssClass("speakernotes");
        boxRight.append(lblNotes);

        // add to root container
        boxRoot.append(boxLeft);
        boxRoot.append(boxRight);

        setChild(boxRoot);

    }

    void setController(PresentationController presentationController) {
        this.presentationController = presentationController;
    }

    void setCurrentSlide(Slide slide) {
        currentSlideView.setSlide(slide);
        if (slide) {
            if (slide.notes) {
                lblNotes.setText(slide.notes.toString);
            }
            else {
                lblNotes.setText(null);
            }
        }
    }

    void setNextSlide(Slide slide) {
        nextSlideView.setSlide(slide);
    }

    void advanceStep(ulong steps) {
        currentSlideView.advanceStep(steps);
    }

    void reverseStep(ulong steps) {
        currentSlideView.reverseStep(steps);
    }
}

class PresentationController {

    size_t currentSlideIdx = 0;
    size_t currentStepIdx = 0;

    SharedVariables vartable;

    Slide currentSlide;
    SlideState[] initialSlideStates;
    SlideState[] slideStepStates;
    Deck deck;

    Signal!() onLastSlide;
    Signal!() onFirstSlide;
    Signal!(ulong) onAdvanceStep;
    Signal!(ulong) onReverseStep;
    Signal!(Slide, ulong) onSlideChanged;

    this(Deck deck, SharedVariables vartable) {

        this.vartable = vartable;

        this.deck = deck;

        initialSlideStates = new SlideState[deck.slides.length];
        for (size_t i; i < initialSlideStates.length; ++i) {
            initialSlideStates[i] = deck.slides[i].getState();
        }

        updateSlideView(currentSlideIdx);
    }

    void showSlide(uint slidenum) {
        if (slidenum < 0 || slidenum > deck.slides.length)
            return;

        currentSlideIdx = slidenum;

        updateSlideView(currentSlideIdx);
    }

    public void advance() {
        if (currentStepIdx < currentSlide.events.length) {
            slideStepStates[currentStepIdx] = currentSlide.getState();
            ++currentStepIdx;
            onAdvanceStep.emit(1);
        }
        else if (currentSlideIdx + 1 < deck.slides.length) {
            ++currentSlideIdx;
            currentStepIdx = 0;
            updateSlideView(currentSlideIdx);
        }
        else {
            onLastSlide.emit();
            writeln("Warning: Cannot advance. Already at end of presentation.");
        }
    }

    public void reverse() {
        if (currentStepIdx > 0) {
            --currentStepIdx;
            currentSlide.setState(slideStepStates[currentStepIdx]);
            onReverseStep.emit(1);
        }
        else if (currentSlideIdx > 0) {
            currentStepIdx = 0;
            --currentSlideIdx;
            updateSlideView(currentSlideIdx);
        }
        else {
            onFirstSlide.emit();
            writeln("Warning: Cannot reverse. Already at start of presentation.");
        }
    }

private:

    void updateSlideView(ulong slidenum) {
        if (slidenum >= deck.slides.length) {
            writeln("ERROR: setting slide index can't be larger than number of slides");
            return;
        }

        vartable["total"] = deck.slides.length;
        vartable["slide"] = slidenum + 1;
        currentSlide = deck.slides[slidenum];
        currentSlide.setState(initialSlideStates[slidenum]);
        slideStepStates = new SlideState[currentSlide.events.length];
        onSlideChanged.emit(currentSlide, slidenum);
    }

}

class SlideView : DrawingArea {

    size_t currentStep = 0;

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

        addCssClass("framed");

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
        currentStep = 0;
        queueDraw();

    }

    bool hasMoreSteps() {
        return currentStep < slide.events.length;
    }

    void advanceStep(ulong step) {
        if (currentStep < slide.events.length) {
            slides.Event event = slide.events[currentStep];
            evaluateFunction(event.func);
            currentStep += step;
            queueDraw();
        }
    }

    void reverseStep(ulong step) {
        if (currentStep > 0) {
            currentStep -= step;
            slides.Event event = slide.events[currentStep];
            // should not run this function. it is meant to be evaluated
            // when advancing into this state, not when reversing back into it.
            // evaluateFunction(event.func);
            queueDraw();
        }
        writeln("TODO: reverseStep(): Not correctly implemented");
    }

    // void setStep(ulong step) {
    //     if (step < 0 || step >= slide.events.length) {
    //         stderr.writeln("ERROR: illegal step");
    //         return;
    //     }

    //     resetState();
    //     for (ulong i; i < step; i++) {
    //         slides.Event event = slide.events[i];
    //         evaluateFunction(event.func);

    //     }
    //     queueDraw();
    // }

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
