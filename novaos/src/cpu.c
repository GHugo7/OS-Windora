/* GDT, IDT, contrôleur d'interruptions (PIC 8259) et gestion des exceptions. */
#include "io.h"
#include "kernel.h"

struct gdt_entry {
    uint16_t limit_low;
    uint16_t base_low;
    uint8_t base_mid;
    uint8_t access;
    uint8_t gran;
    uint8_t base_high;
} __attribute__((packed));

struct idt_entry {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t zero;
    uint8_t flags;
    uint16_t offset_high;
} __attribute__((packed));

struct table_ptr {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

extern void gdt_flush(struct table_ptr *p);
extern void idt_load(struct table_ptr *p);
extern void *isr_stub_table[48];

static struct gdt_entry gdt[3];
static struct idt_entry idt[256];
static irq_handler_t irq_handlers[16];

static const char *const exception_names[32] = {
    "Division par zéro", "Debug", "NMI", "Point d'arrêt",
    "Dépassement", "Hors limites", "Instruction invalide", "Coprocesseur absent",
    "Double faute", "Segment coprocesseur", "TSS invalide", "Segment absent",
    "Faute de pile", "Protection générale", "Défaut de page", "Réservée",
    "Erreur FPU x87", "Alignement", "Machine check", "Erreur SIMD",
    "Virtualisation", "Protection de contrôle", "Réservée", "Réservée",
    "Réservée", "Réservée", "Réservée", "Réservée",
    "Injection hyperviseur", "Communication VMM", "Sécurité", "Réservée",
};

static void gdt_set(int i, uint32_t base, uint32_t limit, uint8_t access, uint8_t gran)
{
    gdt[i].base_low = base & 0xFFFF;
    gdt[i].base_mid = (base >> 16) & 0xFF;
    gdt[i].base_high = (base >> 24) & 0xFF;
    gdt[i].limit_low = limit & 0xFFFF;
    gdt[i].gran = ((limit >> 16) & 0x0F) | (gran & 0xF0);
    gdt[i].access = access;
}

static void gdt_init(void)
{
    static struct table_ptr p;
    gdt_set(0, 0, 0, 0, 0);
    gdt_set(1, 0, 0xFFFFFFFF, 0x9A, 0xCF);  /* code noyau */
    gdt_set(2, 0, 0xFFFFFFFF, 0x92, 0xCF);  /* données noyau */
    p.limit = sizeof(gdt) - 1;
    p.base = (uint32_t)&gdt;
    gdt_flush(&p);
}

static void pic_remap(void)
{
    outb(0x20, 0x11); io_wait();
    outb(0xA0, 0x11); io_wait();
    outb(0x21, 0x20); io_wait();    /* IRQ 0-7  -> vecteurs 32-39 */
    outb(0xA1, 0x28); io_wait();    /* IRQ 8-15 -> vecteurs 40-47 */
    outb(0x21, 0x04); io_wait();
    outb(0xA1, 0x02); io_wait();
    outb(0x21, 0x01); io_wait();
    outb(0xA1, 0x01); io_wait();
    outb(0x21, 0xFF);               /* tout masqué : irq_install() démasque */
    outb(0xA1, 0xFF);
}

static void irq_unmask(int irq)
{
    uint16_t port = irq < 8 ? 0x21 : 0xA1;
    if (irq >= 8) {
        irq -= 8;
        outb(0x21, inb(0x21) & ~(1 << 2));   /* ligne de cascade */
    }
    outb(port, inb(port) & ~(1 << irq));
}

static void idt_init(void)
{
    static struct table_ptr p;
    for (int i = 0; i < 48; i++) {
        uint32_t addr = (uint32_t)isr_stub_table[i];
        idt[i].offset_low = addr & 0xFFFF;
        idt[i].offset_high = addr >> 16;
        idt[i].selector = 0x08;
        idt[i].zero = 0;
        idt[i].flags = 0x8E;    /* présente, ring 0, porte d'interruption 32 bits */
    }
    p.limit = sizeof(idt) - 1;
    p.base = (uint32_t)&idt;
    idt_load(&p);
}

void irq_install(int irq, irq_handler_t handler)
{
    irq_handlers[irq] = handler;
    irq_unmask(irq);
}

static void panic_screen(const char *title)
{
    interrupts_disable();
    console_set_color(COLOR_WHITE, COLOR_RED);
    console_clear();
    kprintf("\n  *** %s : ERREUR FATALE ***\n\n  %s\n\n", OS_NAME, title);
}

void panic(const char *msg)
{
    panic_screen(msg);
    kprintf("  Le système est arrêté. Redémarrez la machine.\n");
    for (;;)
        cpu_halt();
}

void isr_handler(struct regs *r)
{
    if (r->int_no < 32) {
        panic_screen(exception_names[r->int_no]);
        kprintf("  Exception %u, code d'erreur 0x%x\n\n", r->int_no, r->err_code);
        kprintf("  EIP=%p  CS=0x%x  EFLAGS=0x%x\n", (void *)r->eip, r->cs, r->eflags);
        kprintf("  EAX=%p  EBX=%p  ECX=%p  EDX=%p\n", (void *)r->eax, (void *)r->ebx,
                (void *)r->ecx, (void *)r->edx);
        kprintf("  ESI=%p  EDI=%p  EBP=%p  ESP=%p\n", (void *)r->esi, (void *)r->edi,
                (void *)r->ebp, (void *)r->esp);
        if (r->int_no == 14) {
            uint32_t cr2;
            __asm__ volatile("mov %%cr2, %0" : "=r"(cr2));
            kprintf("  Adresse fautive (CR2) = %p\n", (void *)cr2);
        }
        kprintf("\n  Le système est arrêté. Redémarrez la machine.\n");
        for (;;)
            cpu_halt();
    }

    int irq = (int)r->int_no - 32;
    if (irq_handlers[irq])
        irq_handlers[irq](r);
    if (irq >= 8)
        outb(0xA0, 0x20);
    outb(0x20, 0x20);
}

void cpu_init(void)
{
    gdt_init();
    pic_remap();
    idt_init();
}
