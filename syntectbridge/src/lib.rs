use syntect::easy::HighlightLines;
use syntect::highlighting::{Color, Style, ThemeSet};
use syntect::parsing::SyntaxSet;
use std::path::Path;
use std::str;

#[repr(C)]
pub struct DString {
    pub length: usize,
    pub ptr: *const u8,
}

impl From<&str> for DString {
    fn from(s: &str) -> Self {
        Self {
            length: s.len(),
            ptr: s.as_ptr(),
        }
    }
}

impl DString {
    pub fn as_str(&self) -> Result<&str, std::str::Utf8Error> {
        let bytes = unsafe {
            std::slice::from_raw_parts(self.ptr, self.length)
        };

        std::str::from_utf8(bytes)
    }
}

#[repr(C)]
pub struct DColor {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl From<Color> for DColor {
    fn from(c: Color) -> Self {
        Self {
            r: c.r,
            g: c.g,
            b: c.b,
        }
    }
}

#[repr(C)]
pub struct DStyle {
    pub fg: DColor,
    pub bg: DColor,
    pub style: u8,
}

#[repr(C)]
pub struct DStyleString {
    pub text: DString,
    pub style: DStyle,
}

#[repr(C)]
pub struct DSlice<T> {
    pub length: usize,
    pub ptr: *mut T,
}

pub fn to_d_slice(input: Vec<(Style, &str)>) -> DSlice<DStyleString> {
    let mut out: Vec<DStyleString> = Vec::with_capacity(input.len());

    for (style, s) in input {
        out.push(DStyleString {
            style: DStyle {
                fg: DColor::from(style.foreground),
                bg: DColor::from(style.background),
                style: style.font_style.bits(),
            },
            text: DString::from(s),
        });
    }

    let slice = DSlice {
        length: out.len(),
        ptr: out.as_mut_ptr(),
    };

    std::mem::forget(out);

    slice
}

#[unsafe(no_mangle)]
pub extern "C" fn highlight(extension: DString, themename:DString, text: DString) -> DSlice<DStyleString> {
    // Load these once at the start of your program
    let ps = SyntaxSet::load_defaults_newlines();
    // let ts = ThemeSet::load_defaults();

    let syntax = ps.find_syntax_by_extension(extension.as_str().unwrap()).unwrap();
    // InspiredGitHub
    // base16-ocean.light
    let theme = ThemeSet::get_theme(Path::new(themename.as_str().unwrap())).unwrap();
    // &ts.themes["InspiredGitHub"]
    let mut h = HighlightLines::new(syntax, &theme);

    return to_d_slice(h.highlight_line(text.as_str().unwrap(), &ps).unwrap());
}
