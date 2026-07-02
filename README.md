# Introduction

Slide Presenter

Slide Presenter is a presentation application that uses a custom text-based DSL instead of a graphical editor.

Presentations are plain text files that work well with version control, support syntax-highlighted code, allow content reuse through imports, and provide precise control over formatting and layout.

# Building

## Prerequisites

* D compiler
* GTK
* DUB
* GStreamer
* Rust (required for Syntect)

then do the following:

```sh
$ git clone https://github.com/jaapgeurts/slidex
$ cd slidex
$ make
```

This will produce a library in `syntectbridge/target/release/libsyntectbridge.so` which should be available in the link path before running the app. You could do this by:
```sh
$ LD_LIBRARY_PATH=syntectbridge/target/release ./slidex
```
