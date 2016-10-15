#![feature(const_fn, lang_items, unique)]
#![no_std]
#![no_builtins]

extern crate spin;

#[macro_use]
mod vga_buffer;

#[no_mangle]
pub extern fn rust_main() {
    use vga_buffer;

    vga_buffer::clear_screen();
    println!("Welcome to the real world");

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
