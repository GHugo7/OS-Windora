/* Clavier PS/2 (jeu de scancodes 1) en AZERTY ou QWERTY, plus l'entrée du port
 * série pour pouvoir piloter l'OS depuis un terminal (qemu -serial stdio). */
#include "io.h"
#include "kernel.h"

#define DEAD_CIRC  0x1001   /* touche morte ^ */
#define DEAD_TREMA 0x1002   /* touche morte ¨ */
#define COM1       0x3F8
#define BUF_SIZE   256

static const uint16_t azerty_normal[128] = {
    [0x02] = '&', 0xE9, '"', '\'', '(', '-', 0xE8, '_', 0xE7, 0xE0, ')', '=',
    [0x10] = 'a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', DEAD_CIRC, '$',
    [0x1E] = 'q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 0xF9, 0xB2,
    [0x2B] = '*', 'w', 'x', 'c', 'v', 'b', 'n', ',', ';', ':', '!',
    [0x37] = '*', [0x4A] = '-', [0x4E] = '+', [0x56] = '<',
};

static const uint16_t azerty_shift[128] = {
    [0x02] = '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 0xB0, '+',
    [0x10] = 'A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', DEAD_TREMA, 0xA3,
    [0x1E] = 'Q', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M', '%',
    [0x2B] = 0xB5, 'W', 'X', 'C', 'V', 'B', 'N', '?', '.', '/', 0xA7,
    [0x37] = '*', [0x4A] = '-', [0x4E] = '+', [0x56] = '>',
};

static const uint16_t azerty_altgr[128] = {
    [0x03] = '~', '#', '{', '[', '|', '`', '\\', '^', '@', ']', '}',
};

static const uint16_t qwerty_normal[128] = {
    [0x02] = '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=',
    [0x10] = 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']',
    [0x1E] = 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
    [0x2B] = '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/',
    [0x37] = '*', [0x4A] = '-', [0x4E] = '+', [0x56] = '\\',
};

static const uint16_t qwerty_shift[128] = {
    [0x02] = '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+',
    [0x10] = 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}',
    [0x1E] = 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~',
    [0x2B] = '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?',
    [0x37] = '*', [0x4A] = '-', [0x4E] = '+', [0x56] = '|',
};

static enum kb_layout layout = LAYOUT_AZERTY;
static bool shift, ctrl, altgr, caps, extended;
static int dead_key;

static volatile int buffer[BUF_SIZE];
static volatile int head, tail;

static void push(int key)
{
    int next = (head + 1) % BUF_SIZE;
    if (next != tail) {
        buffer[head] = key;
        head = next;
    }
}

int kb_poll(void)
{
    if (head == tail)
        return 0;
    int key = buffer[tail];
    tail = (tail + 1) % BUF_SIZE;
    return key;
}

int kb_getkey(void)
{
    int key;
    while (!(key = kb_poll()))
        cpu_halt();
    return key;
}

void kb_set_layout(enum kb_layout l)
{
    layout = l;
    dead_key = 0;
}

enum kb_layout kb_get_layout(void)
{
    return layout;
}

static int compose(int dead, int c)
{
    static const char vowels[] = "aeiouAOU";
    static const uint16_t circ[] = { 0xE2, 0xEA, 0xEE, 0xF4, 0xFB, 0, 0, 0 };
    static const uint16_t trema[] = { 0xE4, 0xEB, 0xEF, 0xF6, 0xFC, 0xC4, 0xD6, 0xDC };

    for (int i = 0; vowels[i]; i++) {
        if (vowels[i] == c) {
            int r = dead == DEAD_CIRC ? circ[i] : trema[i];
            if (r)
                return r;
        }
    }
    return 0;
}

static void emit(int c)
{
    if (c == DEAD_CIRC || c == DEAD_TREMA) {
        if (dead_key) {   /* deux fois la touche morte : on l'écrit telle quelle */
            push(dead_key == DEAD_CIRC ? '^' : 0xA8);
            dead_key = 0;
        } else {
            dead_key = c;
        }
        return;
    }
    if (dead_key) {
        int d = dead_key, composed = compose(d, c);
        dead_key = 0;
        if (composed) {
            push(composed);
            return;
        }
        push(d == DEAD_CIRC ? '^' : 0xA8);
        if (c == ' ')
            return;
    }
    push(c);
}

static void handle_extended(uint8_t sc, bool released)
{
    switch (sc) {
    case 0x38: altgr = !released; return;
    case 0x1D: ctrl = !released; return;
    }
    if (released)
        return;
    switch (sc) {
    case 0x48: push(KEY_UP); break;
    case 0x50: push(KEY_DOWN); break;
    case 0x4B: push(KEY_LEFT); break;
    case 0x4D: push(KEY_RIGHT); break;
    case 0x47: push(KEY_HOME); break;
    case 0x4F: push(KEY_END); break;
    case 0x53: push(KEY_DELETE); break;
    case 0x1C: push('\n'); break;   /* Entrée du pavé numérique */
    case 0x35: push('/'); break;
    }
}

static void keyboard_irq(struct regs *r)
{
    (void)r;
    uint8_t sc = inb(0x60);

    if (sc == 0xE0) {
        extended = true;
        return;
    }
    bool released = sc & 0x80;
    sc &= 0x7F;

    if (extended) {
        extended = false;
        handle_extended(sc, released);
        return;
    }

    switch (sc) {
    case 0x2A:
    case 0x36: shift = !released; return;
    case 0x1D: ctrl = !released; return;
    case 0x38: return;  /* Alt gauche : ignoré */
    case 0x3A: if (!released) caps = !caps; return;
    }
    if (released)
        return;

    switch (sc) {
    case 0x01: push(KEY_ESC); return;
    case 0x0E: push('\b'); return;
    case 0x0F: push('\t'); return;
    case 0x1C: push('\n'); return;
    case 0x39: emit(' '); return;
    }

    bool az = layout == LAYOUT_AZERTY;
    int c = 0;
    if (altgr && az)
        c = azerty_altgr[sc];
    else if (shift)
        c = az ? azerty_shift[sc] : qwerty_shift[sc];
    else
        c = az ? azerty_normal[sc] : qwerty_normal[sc];
    if (!c)
        return;

    bool letter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
    if (ctrl && letter) {
        push(c & 0x1F);     /* Ctrl+C = 3, Ctrl+L = 12, ... */
        return;
    }
    if (caps && letter)
        c ^= 0x20;
    emit(c);
}

/* Entrée série : octets UTF-8 et séquences d'échappement VT100 pour les flèches. */
static void serial_irq(struct regs *r)
{
    (void)r;
    static int esc_state;
    static uint32_t cp;
    static int need;
    static uint8_t last;

    while (inb(COM1 + 5) & 1) {
        uint8_t b = inb(COM1), prev = last;
        last = b;

        if (esc_state == 1) {
            esc_state = (b == '[' || b == 'O') ? 2 : 0;
            if (!esc_state)
                push(KEY_ESC);
            continue;
        }
        if (esc_state == 2) {
            esc_state = 0;
            switch (b) {
            case 'A': push(KEY_UP); break;
            case 'B': push(KEY_DOWN); break;
            case 'C': push(KEY_RIGHT); break;
            case 'D': push(KEY_LEFT); break;
            case 'H': push(KEY_HOME); break;
            case 'F': push(KEY_END); break;
            }
            continue;
        }

        if (need && (b & 0xC0) == 0x80) {
            cp = (cp << 6) | (b & 0x3F);
            if (--need == 0)
                push((int)cp);
            continue;
        }
        need = 0;

        if (b == 0x1B)
            esc_state = 1;
        else if (b == '\r' || (b == '\n' && prev != '\r'))
            push('\n');
        else if (b == '\n')
            ;   /* fin de ligne \r\n déjà traitée */
        else if (b == 0x7F)
            push('\b');
        else if ((b & 0xE0) == 0xC0)
            cp = b & 0x1F, need = 1;
        else if ((b & 0xF0) == 0xE0)
            cp = b & 0x0F, need = 2;
        else if (b < 0x80)
            push(b);
    }
}

void keyboard_init(void)
{
    while (inb(0x64) & 1)   /* vide le tampon du contrôleur */
        inb(0x60);
    irq_install(1, keyboard_irq);

    outb(COM1 + 1, 0x01);   /* interruption à la réception */
    irq_install(4, serial_irq);
}
