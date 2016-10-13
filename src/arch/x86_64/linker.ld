/* This matches the exported name in boot.asm and the bootloader will jump to
 * it after loading the kernel.
 */
ENTRY(start)

/* First set the load address of the first section to 1MiB. We don't set it to
 * a value before that because there are special memory areas below 1MiB such
 * as the VGA bugger at 0xb8000.
 *
 * Then ensure that the multiboot header is included first. GRUB expects to
 * find the multiboot header very early in the file. This section is followed
 * by executable code.
 */
SECTIONS {
    . = 1M;

    .boot :
    {
        *(.multiboot_header)
    }

    .text :
    {
        *(.text)
    }
}
