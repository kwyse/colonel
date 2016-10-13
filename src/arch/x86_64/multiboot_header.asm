; Section is defined so that the linker can find this header
section .multiboot_header

; This header must adhere to the format outlined in the Multiboot specification:
;
; | name           | size (bits) | recommended value       |
; +                +             +                         +
; | magic number   | 32          | 0xe85250d6              |
; | architecture   | 32          | 0 (i386) or 4 MIPS)     |
; | header length  | 32          |                         |
; | checksum       | 32          | negative of first three |
; | tags           | variable    |                         |
; | end tag        | 16, 16, 32  | 0, 0, 8                 |
;
; 'dw' -> define word (16 bit) constant
; 'dd' -> define double word (32 bit) constant
;
; The magic number is fixed for Multiboot 2.
;
; The checksum must equal zero. The expression within parentheses is negative
; and doesn't fit into a 32 bit unsigned integer, but will if we subtract it
; from 2^32.
;
; The end tag is composed of:
; - type
; - flags
; - size
;
header_start:
    dd 0xe85250d6
    dd 0
    dd header_end - header_start

    dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start))

    dw 0
    dw 0
    dd 8

header_end:
