module sharedvars;

import std.variant;

class SharedVariables {

    Variant opIndex(string name) {
        return vars[name];
    }

    void opIndexAssign(ulong val, string name) {
        vars[name] = val;
    }

    bool contains(string name) {
        return (name in vars) !is null;
    }

private:

    Variant[string] vars;

}
