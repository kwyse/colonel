name ?= colonel
arch ?= x86_64
target ?= $(arch)-unknown-linux-gnu

build_dir := target
kernel := $(build_dir)/kernel-$(arch).bin
iso := $(build_dir)/os-$(arch).iso
rust_src_files := $(shell find . -type f -name '*.rs')
rust_lib := $(build_dir)/$(target)/debug/lib$(name).a

src_dir := src
asm_src_dir := $(src_dir)/arch/$(arch)

asm_src_files := $(wildcard $(asm_src_dir)/*.asm)
asm_obj_files := $(patsubst $(asm_src_dir)/%.asm, $(build_dir)/obj/%.o, $(asm_src_files))
linker_script := $(asm_src_dir)/linker.ld
grub_cfg := $(asm_src_dir)/grub.cfg

.PHONY: clean

all: build

clean:
	@echo Cleaning $(build_dir)
	@cargo clean

build: $(iso)

run: $(iso)
	@echo Running OS
	@qemu-system-x86_64 -cdrom $(iso)

$(iso): $(kernel) $(grub_cfg)
	@echo Creating ISO
	@mkdir -p $(build_dir)/isofiles/boot/grub
	@cp $(kernel) $(build_dir)/isofiles/boot/kernel.bin
	@cp $(grub_cfg) $(build_dir)/isofiles/boot/grub
	@grub-mkrescue -o $(iso) $(build_dir)/isofiles 2> /dev/null

$(kernel): $(linker_script) $(asm_obj_files) $(rust_lib)
	@echo Linking object files
	@mkdir -p $(build_dir)
	@ld -n --gc-sections -o $(kernel) -T $(linker_script) $(asm_obj_files) $(rust_lib)

$(rust_lib): $(rust_src_files)
	@echo Building Rust crate
	@cargo build --target $(target) 2> /dev/null

$(build_dir)/obj/%.o: $(asm_src_dir)/%.asm
	@echo Assembling $< to $@
	@mkdir -p $(build_dir)/obj
	@nasm -f elf64 $< -o $@
