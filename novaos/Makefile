# NovaOS - compile avec le gcc/ld du système (pas besoin de cross-compilateur).

CC      := gcc
LD      ?= ld
QEMU    ?= qemu-system-i386

CFLAGS  := -m32 -std=gnu11 -O2 -g -Wall -Wextra \
           -ffreestanding -fno-builtin -fno-pie -fno-stack-protector \
           -fno-asynchronous-unwind-tables -fno-tree-loop-distribute-patterns \
           -fcf-protection=none \
           -mno-sse -mno-sse2 -mno-mmx -mno-80387 -nostdlib
ASFLAGS := -m32
LDFLAGS := -m elf_i386 -T linker.ld -nostdlib --no-warn-rwx-segments

BUILD   := build
SRCS_C  := $(wildcard src/*.c)
SRCS_S  := $(wildcard src/*.S)
OBJS    := $(SRCS_S:src/%.S=$(BUILD)/%.o) $(SRCS_C:src/%.c=$(BUILD)/%.o)
KERNEL  := $(BUILD)/novaos.elf
ISO     := $(BUILD)/novaos.iso

.PHONY: all run run-serial iso run-iso clean

all: $(KERNEL)

$(BUILD)/%.o: src/%.c src/kernel.h src/io.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/%.o: src/%.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(KERNEL): $(OBJS) linker.ld
	$(LD) $(LDFLAGS) $(OBJS) -o $@

$(BUILD):
	mkdir -p $@

# Démarre le noyau directement (QEMU sait charger un noyau multiboot).
run: $(KERNEL)
	$(QEMU) -kernel $(KERNEL) -m 64M

# Sans fenêtre : l'OS est piloté depuis le terminal via le port série.
run-serial: $(KERNEL)
	$(QEMU) -kernel $(KERNEL) -m 64M -display none -serial stdio

# Image ISO bootable avec GRUB (pour une clé USB ou VirtualBox).
iso: $(ISO)

$(ISO): $(KERNEL) grub.cfg
	mkdir -p $(BUILD)/iso/boot/grub
	cp $(KERNEL) $(BUILD)/iso/boot/novaos.elf
	cp grub.cfg $(BUILD)/iso/boot/grub/grub.cfg
	grub-mkrescue -o $@ $(BUILD)/iso

run-iso: $(ISO)
	$(QEMU) -cdrom $(ISO) -m 64M

clean:
	rm -rf $(BUILD)
