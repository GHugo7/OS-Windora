/* Console texte VGA 80x25, recopiée sur le port série COM1.
 * Le texte est en UTF-8 ; les caractères accentués sont convertis
 * vers la page de code 437 utilisée par la carte VGA. */
#include "io.h"
#include "kernel.h"

#define VGA_MEM ((volatile uint16_t *)0xB8000)
#define COM1    0x3F8

static int cur_x, cur_y;
static uint8_t cur_attr = VGA_ATTR(COLOR_LIGHT_GREY, COLOR_BLACK);

static uint16_t saved_screen[VGA_WIDTH * VGA_HEIGHT];
static int saved_x, saved_y;
static uint8_t saved_attr;

static const struct { uint16_t cp; uint8_t glyph; } cp437_map[] = {
    { 0xE9, 0x82 }, { 0xE8, 0x8A }, { 0xEA, 0x88 }, { 0xEB, 0x89 },
    { 0xE0, 0x85 }, { 0xE2, 0x83 }, { 0xE4, 0x84 }, { 0xE7, 0x87 },
    { 0xF9, 0x97 }, { 0xFB, 0x96 }, { 0xFC, 0x81 }, { 0xF4, 0x93 },
    { 0xF6, 0x94 }, { 0xEE, 0x8C }, { 0xEF, 0x8B }, { 0xC9, 0x90 },
    { 0xC7, 0x80 }, { 0xC4, 0x8E }, { 0xD6, 0x99 }, { 0xDC, 0x9A },
    { 0xB0, 0xF8 }, { 0xB2, 0xFD }, { 0xA3, 0x9C }, { 0xB5, 0xE6 },
    { 0xA7, 0x15 }, { 0xAB, 0xAE }, { 0xBB, 0xAF }, { 0xA8, '"' },
    { 0x2500, 0xC4 }, { 0x2502, 0xB3 }, { 0x2550, 0xCD }, { 0x2551, 0xBA },
    { 0x2554, 0xC9 }, { 0x2557, 0xBB }, { 0x255A, 0xC8 }, { 0x255D, 0xBC },
    { 0x2588, 0xDB }, { 0x2591, 0xB0 }, { 0x2592, 0xB1 }, { 0x2593, 0xB2 },
    { 0x2665, 0x03 }, { 0x2666, 0x04 }, { 0x263A, 0x01 }, { 0x25BA, 0x10 },
};

static uint8_t to_glyph(uint32_t cp)
{
    if (cp < 0x80)
        return (uint8_t)cp;
    for (size_t i = 0; i < sizeof(cp437_map) / sizeof(cp437_map[0]); i++)
        if (cp437_map[i].cp == cp)
            return cp437_map[i].glyph;
    return '?';
}

/* Décodeur UTF-8 incrémental : renvoie true quand *cp contient un caractère complet. */
struct utf8_state {
    uint32_t cp;
    int need;
};

static bool utf8_feed(struct utf8_state *st, uint8_t b, uint32_t *cp)
{
    if (st->need) {
        if ((b & 0xC0) == 0x80) {
            st->cp = (st->cp << 6) | (b & 0x3F);
            if (--st->need == 0) {
                *cp = st->cp;
                return true;
            }
            return false;
        }
        st->need = 0;
    }
    if (b < 0x80) {
        *cp = b;
        return true;
    }
    if ((b & 0xE0) == 0xC0) {
        st->cp = b & 0x1F;
        st->need = 1;
    } else if ((b & 0xF0) == 0xE0) {
        st->cp = b & 0x0F;
        st->need = 2;
    } else if ((b & 0xF8) == 0xF0) {
        st->cp = b & 0x07;
        st->need = 3;
    } else {
        *cp = '?';
        return true;
    }
    return false;
}

/* ---- port série ---- */

static void serial_init(void)
{
    outb(COM1 + 1, 0x00);   /* pas d'interruptions pour l'instant */
    outb(COM1 + 3, 0x80);   /* DLAB */
    outb(COM1 + 0, 0x01);   /* 115200 bauds */
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x03);   /* 8N1 */
    outb(COM1 + 2, 0xC7);   /* FIFO */
    outb(COM1 + 4, 0x0B);   /* DTR, RTS, OUT2 (nécessaire pour l'IRQ) */
}

static void serial_putc(char c)
{
    for (int i = 0; i < 100000 && !(inb(COM1 + 5) & 0x20); i++)
        ;
    outb(COM1, (uint8_t)c);
}

/* ---- écran ---- */

static void update_cursor(void)
{
    uint16_t pos = (uint16_t)(cur_y * VGA_WIDTH + cur_x);
    outb(0x3D4, 0x0F);
    outb(0x3D5, pos & 0xFF);
    outb(0x3D4, 0x0E);
    outb(0x3D5, pos >> 8);
}

void console_cursor(bool visible)
{
    outb(0x3D4, 0x0A);
    outb(0x3D5, visible ? 0x0D : 0x20);
    outb(0x3D4, 0x0B);
    outb(0x3D5, 0x0E);
}

static void scroll(void)
{
    if (cur_y < VGA_HEIGHT)
        return;
    for (int i = 0; i < VGA_WIDTH * (VGA_HEIGHT - 1); i++)
        VGA_MEM[i] = VGA_MEM[i + VGA_WIDTH];
    for (int x = 0; x < VGA_WIDTH; x++)
        VGA_MEM[(VGA_HEIGHT - 1) * VGA_WIDTH + x] = (uint16_t)(' ' | (cur_attr << 8));
    cur_y = VGA_HEIGHT - 1;
}

static void put_codepoint(uint32_t cp)
{
    switch (cp) {
    case '\n':
        cur_x = 0;
        cur_y++;
        break;
    case '\r':
        cur_x = 0;
        break;
    case '\b':
        /* Recule d'une case (éventuellement sur la ligne précédente) et l'efface. */
        if (cur_x > 0) {
            cur_x--;
        } else if (cur_y > 0) {
            cur_y--;
            cur_x = VGA_WIDTH - 1;
        }
        VGA_MEM[cur_y * VGA_WIDTH + cur_x] = (uint16_t)(' ' | (cur_attr << 8));
        break;
    case '\t':
        do
            put_codepoint(' ');
        while (cur_x % 4);
        return;
    default:
        VGA_MEM[cur_y * VGA_WIDTH + cur_x] = (uint16_t)(to_glyph(cp) | (cur_attr << 8));
        if (++cur_x >= VGA_WIDTH) {
            cur_x = 0;
            cur_y++;
        }
        break;
    }
    scroll();
}

void console_putc(char c)
{
    static struct utf8_state st;
    uint32_t cp;

    if (c == '\n')
        serial_putc('\r');
    if (c == '\b') {
        serial_putc('\b');
        serial_putc(' ');
    }
    serial_putc(c);

    if (utf8_feed(&st, (uint8_t)c, &cp)) {
        put_codepoint(cp);
        update_cursor();
    }
}

void console_write(const char *s)
{
    while (*s)
        console_putc(*s++);
}

void console_clear(void)
{
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++)
        VGA_MEM[i] = (uint16_t)(' ' | (cur_attr << 8));
    cur_x = cur_y = 0;
    update_cursor();
    /* Efface aussi un éventuel terminal série. */
    for (const char *s = "\033[2J\033[H"; *s; s++)
        serial_putc(*s);
}

void console_set_color(uint8_t fg, uint8_t bg)
{
    cur_attr = VGA_ATTR(fg, bg);
}

uint8_t console_get_attr(void)
{
    return cur_attr;
}

void console_set_attr(uint8_t attr)
{
    cur_attr = attr;
}

void console_put_at(int x, int y, uint8_t glyph, uint8_t attr)
{
    if (x >= 0 && x < VGA_WIDTH && y >= 0 && y < VGA_HEIGHT)
        VGA_MEM[y * VGA_WIDTH + x] = (uint16_t)(glyph | (attr << 8));
}

void console_print_at(int x, int y, uint8_t attr, const char *utf8)
{
    struct utf8_state st = { 0, 0 };
    uint32_t cp;
    for (; *utf8; utf8++)
        if (utf8_feed(&st, (uint8_t)*utf8, &cp))
            console_put_at(x++, y, to_glyph(cp), attr);
}

void console_save(void)
{
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++)
        saved_screen[i] = VGA_MEM[i];
    saved_x = cur_x;
    saved_y = cur_y;
    saved_attr = cur_attr;
}

void console_restore(void)
{
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++)
        VGA_MEM[i] = saved_screen[i];
    cur_x = saved_x;
    cur_y = saved_y;
    cur_attr = saved_attr;
    update_cursor();
}

void console_init(void)
{
    serial_init();
    console_cursor(true);
    console_clear();
}
