#ifndef KERNEL_H
#define KERNEL_H

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define OS_NAME    "NovaOS"
#define OS_VERSION "0.1"

/* ---- lib.c ---- */
void *memset(void *dst, int c, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
void *memmove(void *dst, const void *src, size_t n);
int memcmp(const void *a, const void *b, size_t n);
size_t strlen(const char *s);
int strcmp(const char *a, const char *b);
int strncmp(const char *a, const char *b, size_t n);
void strlcpy(char *dst, const char *src, size_t size);
int isspace(int c);
int isdigit(int c);
int atoi(const char *s);
void srand(uint32_t seed);
uint32_t rand(void);
int kprintf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
int ksnprintf(char *buf, size_t size, const char *fmt, ...) __attribute__((format(printf, 3, 4)));

/* ---- console.c ---- */
enum vga_color {
    COLOR_BLACK, COLOR_BLUE, COLOR_GREEN, COLOR_CYAN,
    COLOR_RED, COLOR_MAGENTA, COLOR_BROWN, COLOR_LIGHT_GREY,
    COLOR_DARK_GREY, COLOR_LIGHT_BLUE, COLOR_LIGHT_GREEN, COLOR_LIGHT_CYAN,
    COLOR_LIGHT_RED, COLOR_LIGHT_MAGENTA, COLOR_YELLOW, COLOR_WHITE,
};

#define VGA_WIDTH  80
#define VGA_HEIGHT 25
#define VGA_ATTR(fg, bg) ((uint8_t)((fg) | ((bg) << 4)))

void console_init(void);
void console_putc(char c);
void console_write(const char *s);
void console_clear(void);
void console_set_color(uint8_t fg, uint8_t bg);
uint8_t console_get_attr(void);
void console_set_attr(uint8_t attr);
void console_put_at(int x, int y, uint8_t glyph, uint8_t attr);
void console_print_at(int x, int y, uint8_t attr, const char *utf8);
void console_cursor(bool visible);
void console_save(void);
void console_restore(void);

/* ---- cpu.c ---- */
struct regs {
    uint32_t gs, fs, es, ds;
    uint32_t edi, esi, ebp, esp, ebx, edx, ecx, eax;
    uint32_t int_no, err_code;
    uint32_t eip, cs, eflags, useresp, ss;
};

typedef void (*irq_handler_t)(struct regs *r);

void cpu_init(void);
void irq_install(int irq, irq_handler_t handler);
void panic(const char *msg) __attribute__((noreturn));

static inline void interrupts_enable(void)  { __asm__ volatile("sti"); }
static inline void interrupts_disable(void) { __asm__ volatile("cli"); }

/* ---- timer.c ---- */
#define TIMER_HZ 100

struct rtc_time {
    int sec, min, hour, day, month, year;
};

void timer_init(void);
uint32_t timer_ticks(void);
void sleep_ms(uint32_t ms);
void rtc_read(struct rtc_time *t);

/* ---- keyboard.c ---- */
/* Les touches sont des points de code Unicode, ou l'une des valeurs ci-dessous. */
#define KEY_ESC    0x110000
#define KEY_UP     0x110001
#define KEY_DOWN   0x110002
#define KEY_LEFT   0x110003
#define KEY_RIGHT  0x110004
#define KEY_HOME   0x110005
#define KEY_END    0x110006
#define KEY_DELETE 0x110007

enum kb_layout { LAYOUT_AZERTY, LAYOUT_QWERTY };

void keyboard_init(void);
int kb_poll(void);
int kb_getkey(void);
void kb_set_layout(enum kb_layout layout);
enum kb_layout kb_get_layout(void);

/* ---- fs.c ---- */
#define FS_MAX_FILES 32
#define FS_NAME_MAX  32
#define FS_FILE_MAX  4096

struct file {
    bool used;
    char name[FS_NAME_MAX];
    uint32_t size;
    char data[FS_FILE_MAX];
};

void fs_init(void);
struct file *fs_find(const char *name);
struct file *fs_at(int index);
int fs_write(const char *name, const char *data, uint32_t len, bool append);
int fs_remove(const char *name);

/* ---- shell.c / snake.c ---- */
void shell_run(void) __attribute__((noreturn));
void snake_run(void);

/* ---- kernel.c ---- */
extern uint32_t mem_lower_kb, mem_upper_kb;
extern char _kernel_start[], _kernel_end[];
void reboot(void) __attribute__((noreturn));
void poweroff(void) __attribute__((noreturn));

#endif
