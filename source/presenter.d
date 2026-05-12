module presenter;

import std.stdio;
import std.sumtype;

import cairo.Context;
import cairo.ImageSurface;
import cairo.Surface;

import gtk.MainWindow;
import gtk.Main;
import gtk.Widget;

import types;
import slides;

class GtkDrawingVisitor : ItemVisitor {
    Context context;
    GtkAllocation size;
    cairo_text_extents_t extents;

    this(Context context, Widget w) {
        this.context = context;
        w.getAllocation(size);

    }

    void visit(Master master) {
        writeln("TODO: drawing for master data (e.g. setup grid)");
    }

    void visit(Slide slide) {
        with (context) {
            selectFontFace("Vollkorn", CairoFontSlant.NORMAL, CairoFontWeight.NORMAL);
            setFontSize(35);

            setSourceRgb(1, 1, 1);

            paint();

            // find the dimensions of the text so we can center it
            setSourceRgb(0.0, 0.0, 1.0);
            textExtents(slide.name, &extents);
            moveTo(size.width / 2 - extents.width / 2, size.height / 2 - extents.height / 2);
            // moveTo(50,50);
            showText(slide.name);
        }
    }

    void visit(Item item) {
        writeln("TODO: drawing item skipped. it is abstract");
    }

    void visit(Rect rect) {
        writeln("TODO: drawing rect");
        with (context) {
            setSourceRgb(0.384, 0.914, 0.976);
            setLineWidth(5);
            rectangle(56, 150, 32, 32);
            stroke();
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
            (CellLocation cl) {}
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
    }
}

void presentDeck(string[] args, Deck deck) {
    writeln("Slide:  ", deck.slides[0].toString);
    writeln("Master: ", deck.slides[0].master.toString);
    // writeln("DECK: ", deck.slides[0].master.items[0].visible);
    size_t currentSlide = 0;
    // open the gtk window
    Main.init(args);
    MainWindow projectorWin = new MainWindow("Projector",);
    projectorWin.setSizeRequest(960, 600);
    projectorWin.addOnDestroy((Widget w) { quitApp(); });

    bool onDraw(Scoped!Context context, Widget w) {

        GtkDrawingVisitor drawing = new GtkDrawingVisitor(context, w);
        Slide slide = deck.slides[currentSlide];
        slide.accept(drawing);
        foreach (item; slide.master.items)
            item.accept(drawing);
        foreach (item; slide.items)
            item.accept(drawing);

        return true;
    }

    projectorWin.addOnDraw(&onDraw);

    projectorWin.showAll();
    Main.run();

}

void quitApp() {
    writeln("Quitting");
    Main.quit();
}
