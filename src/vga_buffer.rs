use core::fmt::{Result, Write};
use core::ptr::{self, Unique};
use spin::Mutex;

pub static WRITER: Mutex<Writer> = Mutex::new(Writer {
    column_pos: 0,
    color_code: ColorCode::new(Color::LightGreen, Color::Black),
    buffer: unsafe {
        Unique::new(0xb8000 as *mut _)
    }
});

macro_rules! println {
    ($fmt:expr) => (print!(concat!($fmt, "\n")));
    ($fmt:expr, $($arg:tt)*) => (print!(concat!($fmt, "\n"), $($arg)*));
}

macro_rules! print {
    ($($arg:tt)*) => ({
        use core::fmt::Write;

        let mut writer = $crate::vga_buffer::WRITER.lock();
        writer.write_fmt(format_args!($($arg)*)).unwrap();
    });
}

pub fn clear_screen() {
    for _ in 0..BUFFER_HEIGHT {
        println!("");
    }
}

#[derive(Debug, Clone, Copy)]
#[repr(u8)]
pub enum Color {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    Pink = 13,
    Yellow = 14,
    White = 15,
}

#[derive(Debug, Clone, Copy)]
struct ColorCode(u8);

impl ColorCode {
    const fn new(foreground: Color, background: Color) -> Self {
        ColorCode((background as u8) << 4 | (foreground as u8))
    }
}

#[derive(Debug, Clone, Copy)]
#[repr(C)]
struct ScreenChar {
    ascii_char: u8,
    color_code: ColorCode,
}

const BUFFER_WIDTH: usize = 80;
const BUFFER_HEIGHT: usize = 25;
            
struct Buffer {
    chars: [[Volatile<ScreenChar>; BUFFER_WIDTH]; BUFFER_HEIGHT],
}

pub struct Writer {
    column_pos: usize,
    color_code: ColorCode,
    buffer: Unique<Buffer>,
}

impl Writer {
    pub fn write_byte(&mut self, byte: u8) {
        if byte == b'\n' {
            self.insert_newline();
        } else {
            if self.column_pos >= BUFFER_WIDTH {
                self.insert_newline();
            }

            let row = BUFFER_HEIGHT - 1;
            let col = self.column_pos;
            let color_code = self.color_code;
            
            self.buffer().chars[row][col].write(ScreenChar {
                ascii_char: byte,
                color_code: color_code,
            });

            self.column_pos += 1;
        }
    }

    pub fn write_str(&mut self, s: &str) {
        for byte in s.bytes() {
            self.write_byte(byte);
        }
    }

    fn buffer(&mut self) -> &mut Buffer {
        unsafe {
            self.buffer.get_mut()
        }
    }

    fn insert_newline(&mut self) {
        for row in 1..BUFFER_HEIGHT {
            for col in 0..BUFFER_WIDTH {
                let buffer = self.buffer();
                let c = buffer.chars[row][col].read();
                buffer.chars[row - 1][col].write(c);
            }
        }

        self.clear_row(BUFFER_HEIGHT - 1);
        self.column_pos = 0;
    }

    fn clear_row(&mut self, row: usize) {
        let blank = ScreenChar {
            ascii_char: b' ',
            color_code: self.color_code,
        };

        for col in 0..BUFFER_WIDTH {
            self.buffer().chars[row][col].write(blank);
        }
    }
}

impl Write for Writer {
    fn write_str(&mut self, s: &str) -> Result {
        for byte in s.bytes() {
            self.write_byte(byte);
        }

        Ok(())
    }
}

struct Volatile<T>(T);

impl<T> Volatile<T> {
    pub fn read(&self) -> T {
        unsafe {
            ptr::read_volatile(&self.0)
        }
    }

    pub fn write(&mut self, value: T) {
        unsafe {
            ptr::write_volatile(&mut self.0, value);
        }
    }
}
