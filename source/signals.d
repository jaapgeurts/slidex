module signals;

struct Signal(T...) {

    alias Event = void delegate(T);

    void emit(T args) {
        foreach (func; listeners) {
            func(args);
        }
    }

    Event[] listeners;

    void connect(Event dg) {
        listeners ~= dg;
    }

}
