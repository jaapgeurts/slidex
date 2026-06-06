module syntect;


extern (C) {
	struct DString {
		size_t length;
		const char* ptr;
	}

	struct DColor {
		ubyte r;
		ubyte g;
		ubyte b;
	}

	struct DStyle {
		DColor fg;
		DColor bg;
		ubyte font_style;
	}

	struct DStyleString {
		string text;
		DStyle style;
	}

	DStyleString[] highlight(string extension, string themename, string text);
}
