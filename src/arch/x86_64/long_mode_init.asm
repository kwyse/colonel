global long_mode_start
extern rust_main

; Run 64-bit code in a separate file because 32-bit code is invalid.
; `bits 64` forces us to use 64-bit instructions.
;
; Move a value (0x2f592f412f4b2f4f) of size qword (64-bits) to the the
; memory at address 0xb8000. This address corresponds to the top-left
; corner of VGA output and prints 'OKAY' to the screen. The 'hlt'
; instruction stops execution.
section .text
bits 64
long_mode_start:
    call rust_main

    mov rax, 0x2f592f412f4b2f4f
    mov qword [0xb8000], rax
    hlt
