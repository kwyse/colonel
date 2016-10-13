arch ?= x86_64

build_dir := target
kernel := $(build_dir)/kernel-$(arch).bin
iso := $(build_dir)/os-$(arch).iso

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
	@rm -rf $(build_dir)

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

$(kernel): $(linker_script) $(asm_obj_files)
	@echo Linking object files
	@mkdir -p $(build_dir)
	@ld -n -o $(kernel) -T $(linker_script) $(asm_obj_files)

$(build_dir)/obj/%.o: $(asm_src_dir)/%.asm
	@echo Assembling $< to $@
	@mkdir -p $(build_dir)/obj
	@nasm -f elf64 $< -o $@
