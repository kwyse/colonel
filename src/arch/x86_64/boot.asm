; Export 'start' because it is the entry point of our kernel. 'global' is
; similar to a 'public' declaration.
global start

; .text is where executable code belongs. We declare ourselves to be in 32-bit
; protected mode.
section .text
bits 32

; Move a value (0x2f4b2f4f) of size dword (32-bits) to the the memory at
; address 0xb8000. This address corresponds to the top-left corner of
; VGA output and prints 'OK' to the screen. The 'hlt' instruction stops
; execution.
start:
    mov dword [0xb8000], 0x2f4b2f4f
    hlt
