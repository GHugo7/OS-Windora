/* Jeu du serpent, directement dans la mémoire vidéo texte. */
#include "kernel.h"

#define MIN_X 1
#define MAX_X (VGA_WIDTH - 2)
#define MIN_Y 2
#define MAX_Y (VGA_HEIGHT - 2)
#define MAX_LEN ((MAX_X - MIN_X + 1) * (MAX_Y - MIN_Y + 1))

#define ATTR_BG    VGA_ATTR(COLOR_BLACK, COLOR_BLACK)
#define ATTR_WALL  VGA_ATTR(COLOR_DARK_GREY, COLOR_BLACK)
#define ATTR_HEAD  VGA_ATTR(COLOR_YELLOW, COLOR_BLACK)
#define ATTR_BODY  VGA_ATTR(COLOR_LIGHT_GREEN, COLOR_BLACK)
#define ATTR_FOOD  VGA_ATTR(COLOR_LIGHT_RED, COLOR_BLACK)
#define ATTR_TEXT  VGA_ATTR(COLOR_BLACK, COLOR_LIGHT_GREY)

enum dir { UP, DOWN, LEFT, RIGHT };

static uint8_t body_x[MAX_LEN], body_y[MAX_LEN];
static int length, score, best;
static int food_x, food_y;

static bool on_snake(int x, int y)
{
    for (int i = 0; i < length; i++)
        if (body_x[i] == x && body_y[i] == y)
            return true;
    return false;
}

static void place_food(void)
{
    do {
        food_x = MIN_X + (int)(rand() % (MAX_X - MIN_X + 1));
        food_y = MIN_Y + (int)(rand() % (MAX_Y - MIN_Y + 1));
    } while (on_snake(food_x, food_y));
    console_put_at(food_x, food_y, 0x03, ATTR_FOOD);
}

static void draw_header(bool paused)
{
    char line[VGA_WIDTH + 1];
    const char *keys = kb_get_layout() == LAYOUT_AZERTY ? "ZQSD" : "WASD";
    for (int x = 0; x < VGA_WIDTH; x++)
        console_put_at(x, 0, ' ', ATTR_TEXT);
    ksnprintf(line, sizeof(line), " SNAKE   Score : %d   Record : %d   %s", score, best,
              paused ? "[PAUSE]" : "");
    console_print_at(0, 0, ATTR_TEXT, line);
    ksnprintf(line, sizeof(line), "Flèches/%s  P pause  Échap quitter ", keys);
    console_print_at(VGA_WIDTH - 36, 0, ATTR_TEXT, line);
}

static void draw_board(void)
{
    for (int y = 1; y < VGA_HEIGHT; y++)
        for (int x = 0; x < VGA_WIDTH; x++) {
            bool wall = y == MIN_Y - 1 || y == MAX_Y + 1 || x == MIN_X - 1 || x == MAX_X + 1;
            console_put_at(x, y, wall ? 0xB1 : ' ', wall ? ATTR_WALL : ATTR_BG);
        }
}

static int key_to_dir(int key)
{
    bool az = kb_get_layout() == LAYOUT_AZERTY;
    if (key >= 'A' && key <= 'Z')
        key += 32;
    if (key == KEY_UP || key == (az ? 'z' : 'w'))
        return UP;
    if (key == KEY_DOWN || key == 's')
        return DOWN;
    if (key == KEY_LEFT || key == (az ? 'q' : 'a'))
        return LEFT;
    if (key == KEY_RIGHT || key == 'd')
        return RIGHT;
    return -1;
}

static bool opposite(int a, int b)
{
    return (a == UP && b == DOWN) || (a == DOWN && b == UP) ||
           (a == LEFT && b == RIGHT) || (a == RIGHT && b == LEFT);
}

/* Une partie. Renvoie false si le joueur veut quitter. */
static bool play(void)
{
    int dir = RIGHT, next_dir = RIGHT;
    int delay = 12;     /* en ticks (1 tick = 10 ms) */
    bool paused = false;

    length = 4;
    score = 0;
    for (int i = 0; i < length; i++) {
        body_x[i] = (uint8_t)(VGA_WIDTH / 2 - i);
        body_y[i] = VGA_HEIGHT / 2;
    }

    draw_board();
    for (int i = 0; i < length; i++)
        console_put_at(body_x[i], body_y[i], i ? 0xDB : 0x02, i ? ATTR_BODY : ATTR_HEAD);
    place_food();
    draw_header(false);

    uint32_t next_step = timer_ticks() + delay;
    for (;;) {
        int key;
        while ((key = kb_poll())) {
            if (key == KEY_ESC)
                return false;
            if (key == 'p' || key == 'P') {
                paused = !paused;
                draw_header(paused);
            }
            int d = key_to_dir(key);
            if (d >= 0 && !opposite(d, dir))
                next_dir = d;
        }
        if (paused || (int32_t)(next_step - timer_ticks()) > 0) {
            __asm__ volatile("hlt");
            continue;
        }
        next_step = timer_ticks() + delay;
        dir = next_dir;

        int nx = body_x[0], ny = body_y[0];
        switch (dir) {
        case UP: ny--; break;
        case DOWN: ny++; break;
        case LEFT: nx--; break;
        case RIGHT: nx++; break;
        }

        bool eat = nx == food_x && ny == food_y;
        /* La queue avance pendant ce tour, sauf si on mange. */
        if (!eat)
            length--;
        bool dead = nx < MIN_X || nx > MAX_X || ny < MIN_Y || ny > MAX_Y || on_snake(nx, ny);
        if (!eat) {
            console_put_at(body_x[length], body_y[length], ' ', ATTR_BG);
            length++;
        }
        if (dead)
            break;

        if (eat) {
            length++;
            score += 10;
            if (delay > 4 && score % 50 == 0)
                delay--;
        }
        for (int i = length - 1; i > 0; i--) {
            body_x[i] = body_x[i - 1];
            body_y[i] = body_y[i - 1];
        }
        body_x[0] = (uint8_t)nx;
        body_y[0] = (uint8_t)ny;

        console_put_at(body_x[1], body_y[1], 0xDB, ATTR_BODY);
        console_put_at(nx, ny, 0x02, ATTR_HEAD);
        if (eat) {
            if (length == MAX_LEN)
                break;
            place_food();
            if (score > best)
                best = score;
            draw_header(false);
        }
    }

    if (score > best)
        best = score;
    draw_header(false);
    uint8_t box = VGA_ATTR(COLOR_WHITE, COLOR_RED);
    char msg[40];
    ksnprintf(msg, sizeof(msg), "PERDU !  Score : %d", score);
    for (int y = 9; y <= 13; y++)
        for (int x = 20; x < 60; x++)
            console_put_at(x, y, ' ', box);
    console_print_at(40 - (int)strlen(msg) / 2, 10, box, msg);
    console_print_at(23, 12, box, "Entrée : rejouer    Échap : quitter");

    sleep_ms(400);
    while (kb_poll())
        ;
    for (;;) {
        int key = kb_getkey();
        if (key == '\n' || key == ' ')
            return true;
        if (key == KEY_ESC || key == 'q' || key == 'Q')
            return false;
    }
}

void snake_run(void)
{
    console_save();
    console_cursor(false);
    srand(timer_ticks() * 2654435761u + 1);

    while (play())
        ;

    while (kb_poll())
        ;
    console_cursor(true);
    console_restore();
}
