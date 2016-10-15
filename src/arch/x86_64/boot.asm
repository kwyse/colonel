; Export 'start' because it is the entry point of our kernel. `global`
; is similar to a 'public' declaration. `extern` is similar to an
; 'import' statement. It makes a label in another file available for
; use in this file.
global start
extern long_mode_start

; .text is where executable code belongs. We declare ourselves to be
; in 32-bit protected mode, limited to 4GiB memory.
section .text
bits 32

; Update the stack pointer register. It is set to stack_top because
; the stack grows downwards. A `push eax` instruction subtracts 4
; (size of eax in bytes) from `esp` and is equivalent to `mov [esp],
; eax`.
;
; Load the long mode GDT (with `lgdt`). Update the selector registers
; to point to the new GDT as opposed to the old one provided by
; GRUB. The stack, data and extra selector registers should point to
; the GDT offset (in bytes) of the data segment. We then 'far jump' to
; an extern label in another file. This far jump is required to reload
; the code selector (cs) register.
start:
    mov esp, stack_top

    call check_multiboot
    call check_cpuid
    call check_long_mode

    call set_up_page_tables
    call enable_paging

    call set_up_sse

    lgdt [gdt64.pointer]
    mov ax, gdt64.data
    mov ss, ax
    mov ds, ax
    mov es, ax

    jmp gdt64.code:long_mode_start

; The multiboot specification states the boot loader must write this
; magic number to `eax` before loading the kernel. `cmp` sets the zero
; flag if its operands are equal. `jne` will jump if the zero flag is
; not set.
check_multiboot:
    cmp eax, 0x36d76289
    jne .no_multiboot
    ret

.no_multiboot:
    mov al, '0'
    jmp error

; Check that the processor supports CPUID by attempting to flip the ID
; bit (bit 21) in the EFLAGS register. If it can be flipped, CPUID is
; avilable. First, copy EFLAGS into eax via the stack, and copy that
; to ecx. Then attempt to flip the ID bit and copy this value back to
; the EFLAGS register. Then copy the EFLAGS register back to eax (the
; bit will still be flipped if CPUID is supported) and restore the
; original EFLAGS value (stored in ecx). Then compare eax and ecx.
; eax should have the ID bit set if CPUID is supported. ecx will not
; have it set. If they are equal, CPUID is not supported.
check_cpuid:
    pushfd			; EFLAGS value is at the top of the stack
    pop eax			; EFLAGS value is in eax
    mov ecx, eax		; EFLAGS value is in exc and eax

    xor eax, 1 << 21		; eax may have ID bit set
    push eax			; updated EFLAGS value is at the top of the stack
    popfd			; updated EFLAGS value is in EFLAGS register

    pushfd			; updated EFLAGS value MAY be at the top of the stack
    pop eax			; EFLAGS value is in eax
    push ecx			; original EFLAGS value is at the top of the stack
    popfd			; original EFLAGS value is in EFLAGS register

    cmp eax, ecx
    je .no_cpuid
    ret

.no_cpuid:
    mov al, '1'
    jmp error

; Check that the processor supports long (64-bit) mode. If the cpuid
; instruction sets eax to be a value greater than 0x80000000, then
; long mode is supported. First, set eax to this value, then call
; cpuid and see if the value is equal or greater. If it is less (`jb`
; instruction is 'jump if below') then we can't check if long mode is
; supported, as we pass in this value as an argument in the next
; block.
;
; Afterwards, set ask cpuid for extended processor info by calling it
; with 0x80000001 in eax. cpuid will then populate ecx and edx with
; various feature bits. Check if the LM-bit (bit 29) is set in edx. If
; it's not set, we can't enter long mode.
check_long_mode:
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long_mode

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .no_long_mode
    ret

.no_long_mode:
    mov al, '2'
    jmp error

; Page tables translate virtual addresses to physical addresses. Pages
; are 4096 bytes. There are four pages tables, each with 512 8-byte
; entries:
;
; - the Page-Map Level-4 Table (PML4), or P4
; - the Page-Directory Pointer Table (PDP), or P3
; - the Page-Directory Table (PD), or P2
; - the Page Table (PT), or P1
;
; For a given 64-bit virtual address, the following happens:
; 1. Get the address of the P4 table from the CR3 register
; 2. Index the P4 table with bits 39-47 (9 bits, 2^9 == 512 == number of entries)
; 3. Index the P3 table with the next 9 bits
; 4. Index the P2 table with the next 9 bits
; 5. Index the P1 table with the next 9 bits
; 6. Use the remaining 12 bites as the page offset (2^12 == 4096 == page size)
;
; Bits 48-63 aren't used and are all identical to bit 47. They aren't
; used because it would make the available address space
; unnecessarilly large and increase the complexity and cost of address
; translation.
;
; There is always exactly one P4 table. Each P4 entry maps to a P3
; table, each P3 entry maps to a P2 table, and each P2 entry maps to a
; P1 table (512 * 512 * 512 * 512 * 4KiB pages == 2^48 bytes == 256TiB
; of virtual addressable space) Each entry contains a page aligned
; 52-bit physical address of the frame or the next page table. We need
; to identity map the virtaul address to the (identical) physical
; address. We do this by setting the present and writable bits (bits 0
; and 1) of the aligned P3 table address and move it to the first four
; (size of eax) bytes of the P4 table. We repeat for the first four
; bytes of the P3 table.
set_up_page_tables:
    mov eax, p3_table
    or eax, 0b11
    mov [p4_table], eax

    mov eax, p2_table
    or eax, 0b11
    mov [p3_table], eax

    mov ecx, 0

; For the P2 table, we calculate the start address of each 2MiB
; (0x200000) page by multiplying eax by the counter (ecx) and then
; setting the present, writable and huge (bit 8) bits, and then
; assigning this to the ecx'th entry. Once this has been done 512
; times, the P2 table is mapped. This means the first GiB (512 * 2MiB)
; is accessible through the same physical and virtual address.
.map_p2_table:
    mov eax, 0x200000
    mul ecx
    or eax, 0b10000011
    mov [p2_table + ecx * 8], eax

    inc ecx
    cmp ecx, 512
    jne .map_p2_table

    ret

; Move the location of the P4 table to cr3, where the CPU will look
; for it. Then set the Physical Address Extension flag in cr4 and set
; the long mode bit in the EFER register. The EFER register is access
; via ecx. `rdmsr` will read the model specific register (MSR) where
; exc is pointing to (0xc0000080 is the EFER MSR) and put this value
; in eax. `wrmsr` will read the value in eax and put it back in the
; register pointed to by ecx. Finally, set the paging flag in the cr0
; register.
enable_paging:
    mov eax, p4_table
    mov cr3, eax

    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    mov ecx, 0xc0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ret

; Check if Streaming SIMD Extensions (SSE) is supported by querying
; cpuid. If it is, set the bits to prevent SSE instructions generating
; a #UD (Invalid Opcode, 0x6). The cr0 and cr4 registers need to be
; updated. In the cr0 register, the EM bit (coprocessor emulation)
; needs to be cleared and the MP bit (coprocessor monitoring) needs to
; be set. In the cr4 register, set the OSFXSR and OSXMMEXCPT bits.
set_up_sse:
    mov eax, 1
    cpuid
    test edx, 1 << 25
    jz .no_sse

    mov eax, cr0
    and ax, 0xfffb
    or ax, 2
    mov cr0, eax
    mov eax, cr4
    or ax, 0b11 << 9
    mov cr4, eax

    ret

.no_sse:
    mov al, '3'
    jmp error

; Prints `ERR: ` and the current error code (stored in `al`) to screen
; and then halts execution. The first byte in each word is the
; foreground and background color (0x4f is red text on a white
; background). The second byte is the ASCII character (0x52 is R). The
; words are stored in little endian order.
error:
    mov dword [0xb8000], 0x4f524f45 ; RE
    mov dword [0xb8004], 0x4f3a4f52 ; :R
    mov dword [0xb8008], 0x4f204f20 ; [space, space]
    mov byte  [0xb800a], al
    hlt

; This section is for read-only initialized data and appropriate for a
; long mode Global Descriptor Table (GDT). A GDT starts with a
; zero-entry followed by an arbitrary number of segment entries. We
; need one code and one data segment. The code segment has the
; descriptor type, present, read/write, executable and 64-bit flags
; set. The data segment has the descriptor type, present and
; read/write flags set.
;
; dq -> define quad (64-bit) constant
; $ -> the current address
; equ -> give the label preceding it the value of equ's operand
;
; `equ` is used for the labels because we need to calculate the
; offset, not the absolute address.
;
; To load the GDT, we need to format it. The first two bytes must be
; the length of the GDT minus one. The following eight bytes must
; specify the GDT address.
section .rodata
gdt64:
    dq 0

.code equ $ - gdt64
    dq (1 << 44) | (1 << 47) | (1 << 41) | (1 << 43) | (1 << 53)

.data equ $ - gdt64
    dq (1 << 44) | (1 << 47) | (1 << 41)

.pointer:
    dw $ - gdt64 - 1
    dq gdt64

; The .bss section is represented by zero-value bits initially. Its
; size is recorded and required at runtime but it will not take up any
; space in the object file.
;
; `align` ensures our page tables are page aligned. By adding them to
; the .bss section, we can page align the whole section and don't have
; to worry about unused padding bytes. The .bss section will be
; initialized to zero, so page tables will contain non-present entries
; (the first bit in each entry is the the 'present' bit).
;
; resb -> reserve byte (without initializing)
;
; We reserve 64 bytes of uninitialized memory for the stack.
;
section .bss
align 4096
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
    resb 64

stack_top:
