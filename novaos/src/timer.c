/* Horloge système (PIT à 100 Hz) et lecture de l'heure (RTC CMOS). */
#include "io.h"
#include "kernel.h"

static volatile uint32_t ticks;

static void timer_irq(struct regs *r)
{
    (void)r;
    ticks++;
}

void timer_init(void)
{
    uint32_t divisor = 1193182 / TIMER_HZ;
    outb(0x43, 0x36);
    outb(0x40, divisor & 0xFF);
    outb(0x40, (divisor >> 8) & 0xFF);
    irq_install(0, timer_irq);
}

uint32_t timer_ticks(void)
{
    return ticks;
}

void sleep_ms(uint32_t ms)
{
    uint32_t end = ticks + (ms * TIMER_HZ + 999) / 1000;
    while ((int32_t)(end - ticks) > 0)
        cpu_halt();
}

static uint8_t cmos_read(uint8_t reg)
{
    outb(0x70, reg);
    return inb(0x71);
}

static int bcd(int v)
{
    return (v & 0x0F) + (v >> 4) * 10;
}

void rtc_read(struct rtc_time *t)
{
    while (cmos_read(0x0A) & 0x80)
        ;   /* mise à jour en cours */

    t->sec = cmos_read(0x00);
    t->min = cmos_read(0x02);
    t->hour = cmos_read(0x04);
    t->day = cmos_read(0x07);
    t->month = cmos_read(0x08);
    t->year = cmos_read(0x09);

    uint8_t status_b = cmos_read(0x0B);
    bool pm = t->hour & 0x80;
    t->hour &= 0x7F;
    if (!(status_b & 0x04)) {
        t->sec = bcd(t->sec);
        t->min = bcd(t->min);
        t->hour = bcd(t->hour);
        t->day = bcd(t->day);
        t->month = bcd(t->month);
        t->year = bcd(t->year);
    }
    if (!(status_b & 0x02) && pm)
        t->hour = (t->hour + 12) % 24;
    t->year += 2000;
}
