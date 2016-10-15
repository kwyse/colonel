#![feature(lang_items)]
#![no_std]
#![no_builtins]

#[no_mangle]
pub extern fn rust_main() {
    let x = ["Hello", "world", "!"];
    let y = x;
    let test = (0..3).flat_map(|x| 0..x).zip(0..);

    let hello = b"Hello world!";
    let color_byte = 0x1f;

    let mut hello_colored = [color_byte; 24];
    for (i, char_byte) in hello.into_iter().enumerate() {
        hello_colored[i * 2] = *char_byte;
    }

    let buffer_ptr = (0xb8000 + 1988) as *mut _;
    unsafe {
        *buffer_ptr = hello_colored
    }

    loop {}
}

#[lang = "eh_personality"]
extern fn eh_personality() {
}

#[lang = "panic_fmt"]
extern fn panic_fmt() -> ! {
    let vga_buffer_ptr = (0xb8000 + 1988) as *mut _;
    let color = 0x4f;

    unsafe {
        *vga_buffer_ptr = [
            b'O', color,
            b'h', color,
            b' ', color,
            b'n', color,
            b'o', color,
            b'!', color
        ];
    };

    loop {}
}

/// rustc expects some essential functions to already be implemented
#[no_mangle]
pub unsafe extern fn memcpy(dest: *mut u8, src: *const u8, n: usize) -> *mut u8 {
    for i in 0..n {
        *dest.offset(i as isize) = *src.offset(i as isize);
    }

    dest
}

/// This is a dummy implementation and never called because our panic
/// strategy is to abort. It prevents undefined reference linker errors.
#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn _Unwind_Resume() -> ! {
    loop {}
}
