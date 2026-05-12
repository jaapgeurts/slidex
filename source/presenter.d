module presenter;

import std.stdio;

import cairo.Context;

import gtk.MainWindow;
import gtk.Main;
import gtk.Widget;

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

            setSourceRgba(0.8, 0.5, 0.2, 1);
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
            setSourceRgba(0.384, 0.914, 0.976, 1.0);
            setLineWidth(5);
            rectangle(56, 150, 32, 32);
            stroke();
        }
    }

    void visit(Image image) {
        writeln("TODO: drawing image");
    }

    void visit(Text text) {
        writeln("TODO: drawing text");
    }
}

void presentDeck(string[] args, Deck deck) {
    writeln("DECK: ", deck.slides[0].toString);
    writeln("DECK: ", deck.slides[0].master.toString);
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
