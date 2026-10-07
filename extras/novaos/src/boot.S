/* Point d'entrée : en-tête multiboot, pile, puis saut vers kmain(). */

.set MB_MAGIC,    0x1BADB002
.set MB_FLAGS,    (1 << 0) | (1 << 1)      /* modules alignés + infos mémoire */
.set MB_CHECKSUM, -(MB_MAGIC + MB_FLAGS)

.section .multiboot
.align 4
.long MB_MAGIC
.long MB_FLAGS
.long MB_CHECKSUM

.section .bss
.align 16
stack_bottom:
.skip 32768
stack_top:

.section .text
.global _start
.type _start, @function
_start:
    mov $stack_top, %esp
    push %ebx               /* pointeur vers les infos multiboot */
    push %eax               /* magic multiboot */
    call kmain
    cli
1:  hlt
    jmp 1b

/* void gdt_flush(struct gdt_ptr *p) */
.global gdt_flush
gdt_flush:
    mov 4(%esp), %eax
    lgdt (%eax)
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    ljmp $0x08, $.Lflush
.Lflush:
    ret

/* void idt_load(struct idt_ptr *p) */
.global idt_load
idt_load:
    mov 4(%esp), %eax
    lidt (%eax)
    ret

.section .note.GNU-stack, "", @progbits
