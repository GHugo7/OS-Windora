/* Point d'entrée C du noyau. */
#include "io.h"
#include "kernel.h"

#define MULTIBOOT_MAGIC 0x2BADB002

uint32_t mem_lower_kb, mem_upper_kb;

void reboot(void)
{
    interrupts_disable();
    /* Impulsion de reset via le contrôleur clavier. */
    for (int i = 0; i < 100000 && (inb(0x64) & 0x02); i++)
        ;
    outb(0x64, 0xFE);
    /* Sinon : triple faute avec une IDT vide. */
    static const struct { uint16_t limit; uint32_t base; } __attribute__((packed)) null_idt = { 0, 0 };
    __asm__ volatile("lidt %0; int $3" : : "m"(null_idt));
    for (;;)
        cpu_halt();
}

void poweroff(void)
{
    interrupts_disable();
    outw(0x604, 0x2000);    /* QEMU récent */
    outw(0xB004, 0x2000);   /* Bochs / ancien QEMU */
    outw(0x4004, 0x3400);   /* VirtualBox */
    console_set_color(COLOR_YELLOW, COLOR_BLACK);
    console_clear();
    kprintf("\n\n\n\n\n\n\n\n\n\n\n                 Vous pouvez éteindre votre ordinateur.\n");
    for (;;)
        cpu_halt();
}

static void boot_step(const char *what)
{
    kprintf("  [");
    console_set_color(COLOR_LIGHT_GREEN, COLOR_BLACK);
    kprintf(" OK ");
    console_set_color(COLOR_LIGHT_GREY, COLOR_BLACK);
    kprintf("] %s\n", what);
}

void kmain(uint32_t magic, uint32_t *mbi)
{
    console_init();

    if (magic != MULTIBOOT_MAGIC)
        panic("Pas démarré par un chargeur multiboot.");
    if (mbi[0] & 1) {
        mem_lower_kb = mbi[1];
        mem_upper_kb = mbi[2];
    }

    kprintf("Démarrage de %s %s...\n\n", OS_NAME, OS_VERSION);
    cpu_init();
    boot_step("GDT, IDT et PIC");
    timer_init();
    boot_step("Horloge (PIT 100 Hz)");
    keyboard_init();
    boot_step("Clavier PS/2 et port série");
    fs_init();
    boot_step("Système de fichiers en mémoire");
    interrupts_enable();

    kprintf("\n  %u Mo de mémoire détectés.\n", (mem_upper_kb + 1024) / 1024);
    kprintf("  Tapez 'help' pour la liste des commandes, 'about' pour en savoir plus.\n\n");

    shell_run();
}
