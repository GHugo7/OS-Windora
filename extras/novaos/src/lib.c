/* Mini bibliothèque C : chaînes, mémoire, printf, aléatoire. */
#include "kernel.h"

void *memset(void *dst, int c, size_t n)
{
    uint8_t *d = dst;
    while (n--)
        *d++ = (uint8_t)c;
    return dst;
}

void *memcpy(void *dst, const void *src, size_t n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    while (n--)
        *d++ = *s++;
    return dst;
}

void *memmove(void *dst, const void *src, size_t n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    if (d < s) {
        while (n--)
            *d++ = *s++;
    } else {
        while (n--)
            d[n] = s[n];
    }
    return dst;
}

int memcmp(const void *a, const void *b, size_t n)
{
    const uint8_t *x = a, *y = b;
    for (; n; n--, x++, y++)
        if (*x != *y)
            return *x - *y;
    return 0;
}

size_t strlen(const char *s)
{
    size_t n = 0;
    while (s[n])
        n++;
    return n;
}

int strcmp(const char *a, const char *b)
{
    while (*a && *a == *b)
        a++, b++;
    return (uint8_t)*a - (uint8_t)*b;
}

int strncmp(const char *a, const char *b, size_t n)
{
    for (; n; n--, a++, b++) {
        if (*a != *b)
            return (uint8_t)*a - (uint8_t)*b;
        if (!*a)
            return 0;
    }
    return 0;
}

void strlcpy(char *dst, const char *src, size_t size)
{
    if (!size)
        return;
    size_t i = 0;
    for (; i + 1 < size && src[i]; i++)
        dst[i] = src[i];
    dst[i] = 0;
}

int isspace(int c)
{
    return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

int isdigit(int c)
{
    return c >= '0' && c <= '9';
}

int atoi(const char *s)
{
    int sign = 1, v = 0;
    while (isspace(*s))
        s++;
    if (*s == '-' || *s == '+')
        sign = (*s++ == '-') ? -1 : 1;
    while (isdigit(*s))
        v = v * 10 + (*s++ - '0');
    return v * sign;
}

static uint32_t rand_state = 1;

void srand(uint32_t seed)
{
    rand_state = seed ? seed : 1;
}

uint32_t rand(void)
{
    rand_state = rand_state * 1103515245u + 12345u;
    return (rand_state >> 16) & 0x7FFF;
}

/* ---- printf ---- */

typedef void (*out_fn)(char c, void *ctx);

static int out_pad(out_fn out, void *ctx, char c, int n)
{
    int i;
    for (i = 0; i < n; i++)
        out(c, ctx);
    return i < 0 ? 0 : i;
}

static int out_num(out_fn out, void *ctx, uint32_t v, unsigned base, bool upper,
                   bool neg, int width, bool zero, bool left)
{
    const char *digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    char tmp[12];
    int n = 0, count = 0;

    do {
        tmp[n++] = digits[v % base];
        v /= base;
    } while (v);

    int len = n + (neg ? 1 : 0);
    int pad = width > len ? width - len : 0;

    if (!left && !zero)
        count += out_pad(out, ctx, ' ', pad);
    if (neg) {
        out('-', ctx);
        count++;
    }
    if (!left && zero)
        count += out_pad(out, ctx, '0', pad);
    while (n) {
        out(tmp[--n], ctx);
        count++;
    }
    if (left)
        count += out_pad(out, ctx, ' ', pad);
    return count;
}

static int kvprintf(out_fn out, void *ctx, const char *fmt, va_list ap)
{
    int count = 0;

    for (; *fmt; fmt++) {
        if (*fmt != '%') {
            out(*fmt, ctx);
            count++;
            continue;
        }
        fmt++;

        bool left = false, zero = false;
        for (;; fmt++) {
            if (*fmt == '-')
                left = true;
            else if (*fmt == '0')
                zero = true;
            else
                break;
        }
        int width = 0;
        while (isdigit(*fmt))
            width = width * 10 + (*fmt++ - '0');

        switch (*fmt) {
        case 'd':
        case 'i': {
            int v = va_arg(ap, int);
            uint32_t u = v < 0 ? -(uint32_t)v : (uint32_t)v;
            count += out_num(out, ctx, u, 10, false, v < 0, width, zero, left);
            break;
        }
        case 'u':
            count += out_num(out, ctx, va_arg(ap, uint32_t), 10, false, false, width, zero, left);
            break;
        case 'x':
        case 'X':
            count += out_num(out, ctx, va_arg(ap, uint32_t), 16, *fmt == 'X', false, width, zero, left);
            break;
        case 'p':
            out('0', ctx);
            out('x', ctx);
            count += 2 + out_num(out, ctx, (uint32_t)va_arg(ap, void *), 16, false, false, 8, true, false);
            break;
        case 'c':
            out((char)va_arg(ap, int), ctx);
            count++;
            break;
        case 's': {
            const char *s = va_arg(ap, const char *);
            if (!s)
                s = "(null)";
            int len = (int)strlen(s);
            int pad = width > len ? width - len : 0;
            if (!left)
                count += out_pad(out, ctx, ' ', pad);
            for (; *s; s++, count++)
                out(*s, ctx);
            if (left)
                count += out_pad(out, ctx, ' ', pad);
            break;
        }
        case '%':
            out('%', ctx);
            count++;
            break;
        case 0:
            return count;
        default:
            out('%', ctx);
            out(*fmt, ctx);
            count += 2;
            break;
        }
    }
    return count;
}

static void console_out(char c, void *ctx)
{
    (void)ctx;
    console_putc(c);
}

int kprintf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int n = kvprintf(console_out, NULL, fmt, ap);
    va_end(ap);
    return n;
}

struct buf_ctx {
    char *buf;
    size_t size, pos;
};

static void buf_out(char c, void *ctx)
{
    struct buf_ctx *b = ctx;
    if (b->pos + 1 < b->size)
        b->buf[b->pos] = c;
    b->pos++;
}

int ksnprintf(char *buf, size_t size, const char *fmt, ...)
{
    struct buf_ctx b = { buf, size, 0 };
    va_list ap;
    va_start(ap, fmt);
    int n = kvprintf(buf_out, &b, fmt, ap);
    va_end(ap);
    if (size)
        buf[b.pos < size ? b.pos : size - 1] = 0;
    return n;
}
