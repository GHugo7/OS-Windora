/* Interpréteur de commandes : édition de ligne, historique, complétion. */
#include "kernel.h"

#define LINE_MAX     256
#define MAX_ARGS     16
#define HISTORY_SIZE 16

struct command {
    const char *name;
    const char *args;
    const char *help;
    void (*run)(int argc, char **argv, const char *rest);
};

static const struct command commands[];
static char history[HISTORY_SIZE][LINE_MAX];
static int history_count;

/* ---- affichage ---- */

static void color_print(uint8_t fg, const char *s)
{
    uint8_t old = console_get_attr();
    console_set_color(fg, old >> 4);
    console_write(s);
    console_set_attr(old);
}

static void prompt(void)
{
    color_print(COLOR_LIGHT_GREEN, OS_NAME);
    color_print(COLOR_LIGHT_BLUE, " > ");
}

static void error(const char *fmt, const char *arg)
{
    uint8_t old = console_get_attr();
    console_set_color(COLOR_LIGHT_RED, old >> 4);
    kprintf(fmt, arg);
    console_set_attr(old);
}

/* ---- édition de ligne ---- */

static int utf8_encode(uint32_t cp, char *out)
{
    if (cp < 0x80) {
        out[0] = (char)cp;
        return 1;
    }
    if (cp < 0x800) {
        out[0] = (char)(0xC0 | (cp >> 6));
        out[1] = (char)(0x80 | (cp & 0x3F));
        return 2;
    }
    out[0] = (char)(0xE0 | (cp >> 12));
    out[1] = (char)(0x80 | ((cp >> 6) & 0x3F));
    out[2] = (char)(0x80 | (cp & 0x3F));
    return 3;
}

/* Nombre de caractères affichés (et non d'octets) d'une chaîne UTF-8. */
static int utf8_width(const char *s, int len)
{
    int n = 0;
    for (int i = 0; i < len; i++)
        if (((uint8_t)s[i] & 0xC0) != 0x80)
            n++;
    return n;
}

static void erase_line(const char *buf, int len)
{
    for (int n = utf8_width(buf, len); n > 0; n--)
        console_putc('\b');
}

/* Complète le dernier mot : nom de commande pour le premier mot, sinon nom de fichier. */
static int complete(char *buf, int len)
{
    int start = len;
    while (start > 0 && buf[start - 1] != ' ')
        start--;
    const char *word = buf + start;
    int wlen = len - start;
    bool is_command = true;
    for (int i = 0; i < start; i++)
        if (buf[i] != ' ')
            is_command = false;

    const char *candidates[64];
    int count = 0;
    if (is_command) {
        for (const struct command *c = commands; c->name && count < 64; c++)
            if (!strncmp(c->name, word, wlen))
                candidates[count++] = c->name;
    } else {
        for (int i = 0; i < FS_MAX_FILES && count < 64; i++) {
            struct file *f = fs_at(i);
            if (f && !strncmp(f->name, word, wlen))
                candidates[count++] = f->name;
        }
    }

    if (count == 0)
        return len;

    /* Préfixe commun à tous les candidats. */
    int common = (int)strlen(candidates[0]);
    for (int i = 1; i < count; i++) {
        int j = 0;
        while (j < common && candidates[i][j] == candidates[0][j])
            j++;
        common = j;
    }

    if (count > 1 && common == wlen) {
        console_putc('\n');
        for (int i = 0; i < count; i++)
            kprintf("%s  ", candidates[i]);
        console_putc('\n');
        prompt();
        buf[len] = 0;
        console_write(buf);
        return len;
    }

    for (int j = wlen; j < common && len < LINE_MAX - 2; j++) {
        buf[len++] = candidates[0][j];
        console_putc(candidates[0][j]);
    }
    if (count == 1 && len < LINE_MAX - 2) {
        buf[len++] = ' ';
        console_putc(' ');
    }
    return len;
}

static void readline(char *buf)
{
    int len = 0;
    int hist_pos = history_count;

    for (;;) {
        int key = kb_getkey();

        if (key == '\n') {
            console_putc('\n');
            buf[len] = 0;
            return;
        }
        if (key == '\b') {
            if (len > 0) {
                do
                    len--;
                while (len > 0 && ((uint8_t)buf[len] & 0xC0) == 0x80);
                console_putc('\b');
            }
        } else if (key == 3) {              /* Ctrl+C */
            console_write("^C\n");
            buf[0] = 0;
            return;
        } else if (key == 12) {             /* Ctrl+L */
            console_clear();
            prompt();
            buf[len] = 0;
            console_write(buf);
        } else if (key == '\t') {
            len = complete(buf, len);
        } else if (key == KEY_UP || key == KEY_DOWN) {
            int first = history_count > HISTORY_SIZE ? history_count - HISTORY_SIZE : 0;
            int pos = hist_pos + (key == KEY_UP ? -1 : 1);
            if (pos < first || pos > history_count)
                continue;
            hist_pos = pos;
            erase_line(buf, len);
            if (pos == history_count)
                buf[0] = 0;
            else
                strlcpy(buf, history[pos % HISTORY_SIZE], LINE_MAX);
            len = (int)strlen(buf);
            console_write(buf);
        } else if (key >= ' ' && key < 0x110000 && key != 0x7F) {
            char enc[3];
            int n = utf8_encode((uint32_t)key, enc);
            if (len + n < LINE_MAX - 1) {
                for (int i = 0; i < n; i++) {
                    buf[len++] = enc[i];
                    console_putc(enc[i]);
                }
            }
        }
    }
}

/* ---- découpage en arguments (les "guillemets" regroupent des mots) ---- */

static int parse_args(char *line, char **argv)
{
    int argc = 0;
    char *p = line;
    while (*p && argc < MAX_ARGS) {
        while (*p == ' ')
            p++;
        if (!*p)
            break;
        if (*p == '"') {
            argv[argc++] = ++p;
            while (*p && *p != '"')
                p++;
        } else {
            argv[argc++] = p;
            while (*p && *p != ' ')
                p++;
        }
        if (*p)
            *p++ = 0;
    }
    return argc;
}

/* Saute n mots dans la ligne brute et renvoie la suite. */
static const char *skip_words(const char *s, int n)
{
    while (n--) {
        while (*s == ' ')
            s++;
        while (*s && *s != ' ')
            s++;
    }
    while (*s == ' ')
        s++;
    return s;
}

/* ---- commandes ---- */

static void cmd_help(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    kprintf("Commandes disponibles :\n\n");
    for (const struct command *c = commands; c->name; c++) {
        char usage[40];
        ksnprintf(usage, sizeof(usage), "%s %s", c->name, c->args);
        uint8_t old = console_get_attr();
        console_set_color(COLOR_YELLOW, old >> 4);
        kprintf("  %-26s", usage);
        console_set_attr(old);
        kprintf("%s\n", c->help);
    }
    kprintf("\nTab complète, flèches haut/bas = historique, Ctrl+L efface l'écran.\n");
}

static void cmd_clear(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    console_clear();
}

static void cmd_echo(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv;
    kprintf("%s\n", rest);
}

static void print_logo(void)
{
    static const char *const logo[] = {
        "  ███╗   ██╗ ██████╗ ██╗   ██╗ █████╗ ",
        "  ████╗  ██║██╔═══██╗██║   ██║██╔══██╗",
        "  ██╔██╗ ██║██║   ██║██║   ██║███████║",
        "  ██║╚██╗██║██║   ██║╚██╗ ██╔╝██╔══██║",
        "  ██║ ╚████║╚██████╔╝ ╚████╔╝ ██║  ██║",
        "  ╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═╝",
    };
    static const uint8_t colors[] = {
        COLOR_LIGHT_CYAN, COLOR_LIGHT_CYAN, COLOR_CYAN,
        COLOR_LIGHT_BLUE, COLOR_LIGHT_BLUE, COLOR_BLUE,
    };
    for (int i = 0; i < 6; i++) {
        color_print(colors[i], logo[i]);
        console_putc('\n');
    }
}

static void print_uptime(void)
{
    uint32_t s = timer_ticks() / TIMER_HZ;
    kprintf("%uh %02um %02us", s / 3600, (s / 60) % 60, s % 60);
}

static void cmd_about(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    print_logo();
    kprintf("\n  %s version %s - noyau 32 bits x86 fait maison\n", OS_NAME, OS_VERSION);
    kprintf("  Mémoire  : %u Mo\n", (mem_upper_kb + 1024) / 1024);
    kprintf("  Clavier  : %s\n", kb_get_layout() == LAYOUT_AZERTY ? "AZERTY" : "QWERTY");
    kprintf("  Allumé   : ");
    print_uptime();
    kprintf("\n");
}

static void cmd_uptime(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    kprintf("Allumé depuis ");
    print_uptime();
    kprintf("\n");
}

static void cmd_date(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    static const char *const days[] = {
        "dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi",
    };
    static const char *const months[] = {
        "janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "août", "septembre", "octobre", "novembre", "décembre",
    };
    struct rtc_time t;
    rtc_read(&t);

    /* Jour de la semaine (algorithme de Sakamoto). */
    static const int offs[] = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 };
    int y = t.year - (t.month < 3);
    int wd = (y + y / 4 - y / 100 + y / 400 + offs[(t.month - 1) % 12] + t.day) % 7;

    kprintf("%s %d %s %d, %02d:%02d:%02d (UTC)\n", days[wd], t.day,
            months[(t.month - 1) % 12], t.year, t.hour, t.min, t.sec);
}

static void cmd_mem(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    uint32_t kstart = (uint32_t)_kernel_start, kend = (uint32_t)_kernel_end;
    kprintf("Mémoire basse  : %u Ko\n", mem_lower_kb);
    kprintf("Mémoire haute  : %u Ko (%u Mo)\n", mem_upper_kb, mem_upper_kb / 1024);
    kprintf("Noyau          : %p - %p (%u Ko)\n", (void *)kstart, (void *)kend,
            (kend - kstart) / 1024);
}

static const char *const color_names[16] = {
    "noir", "bleu", "vert", "cyan", "rouge", "magenta", "marron", "gris",
    "grisfonce", "bleuclair", "vertclair", "cyanclair", "rose", "magentaclair",
    "jaune", "blanc",
};

static int parse_color(const char *s)
{
    if (isdigit(s[0])) {
        int v = atoi(s);
        return v >= 0 && v < 16 ? v : -1;
    }
    for (int i = 0; i < 16; i++)
        if (!strcmp(s, color_names[i]))
            return i;
    return -1;
}

static void cmd_color(int argc, char **argv, const char *rest)
{
    (void)rest;
    int fg = argc > 1 ? parse_color(argv[1]) : -1;
    int bg = argc > 2 ? parse_color(argv[2]) : (console_get_attr() >> 4);
    if (fg < 0 || bg < 0 || bg > 7) {
        kprintf("Usage : color <texte> [fond]   (fond : 0 à 7 seulement)\n");
        for (int i = 0; i < 16; i++) {
            uint8_t old = console_get_attr();
            console_set_color((uint8_t)i, i == 0 ? COLOR_LIGHT_GREY : COLOR_BLACK);
            kprintf(" %2d %-13s", i, color_names[i]);
            console_set_attr(old);
            if (i % 4 == 3)
                console_putc('\n');
        }
        return;
    }
    console_set_color((uint8_t)fg, (uint8_t)bg);
    console_clear();
}

static void cmd_layout(int argc, char **argv, const char *rest)
{
    (void)rest;
    if (argc > 1 && !strcmp(argv[1], "azerty"))
        kb_set_layout(LAYOUT_AZERTY);
    else if (argc > 1 && !strcmp(argv[1], "qwerty"))
        kb_set_layout(LAYOUT_QWERTY);
    else if (argc > 1)
        error("Disposition inconnue : %s (azerty ou qwerty)\n", argv[1]);
    kprintf("Clavier : %s\n", kb_get_layout() == LAYOUT_AZERTY ? "AZERTY" : "QWERTY");
}

static void cmd_ls(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    int count = 0;
    uint32_t total = 0;
    for (int i = 0; i < FS_MAX_FILES; i++) {
        struct file *f = fs_at(i);
        if (!f)
            continue;
        kprintf("  %6u  ", f->size);
        color_print(COLOR_LIGHT_CYAN, f->name);
        console_putc('\n');
        count++;
        total += f->size;
    }
    kprintf("%d fichier(s), %u octets\n", count, total);
}

static void cmd_cat(int argc, char **argv, const char *rest)
{
    (void)rest;
    if (argc < 2) {
        kprintf("Usage : cat <fichier>\n");
        return;
    }
    for (int i = 1; i < argc; i++) {
        struct file *f = fs_find(argv[i]);
        if (!f) {
            error("Fichier introuvable : %s\n", argv[i]);
            continue;
        }
        for (uint32_t j = 0; j < f->size; j++)
            console_putc(f->data[j]);
        if (f->size && f->data[f->size - 1] != '\n')
            console_putc('\n');
    }
}

static void write_file(int argc, char **argv, const char *rest, bool append)
{
    if (argc < 2) {
        kprintf("Usage : %s <fichier> <texte>\n", argv[0]);
        return;
    }
    const char *text = skip_words(rest, 1);
    char data[LINE_MAX + 1];
    ksnprintf(data, sizeof(data), "%s\n", text);
    if (fs_write(argv[1], data, strlen(data), append) < 0)
        error("Impossible d'écrire %s (nom trop long ou disque plein)\n", argv[1]);
}

static void cmd_write(int argc, char **argv, const char *rest)
{
    write_file(argc, argv, rest, false);
}

static void cmd_append(int argc, char **argv, const char *rest)
{
    write_file(argc, argv, rest, true);
}

static void cmd_rm(int argc, char **argv, const char *rest)
{
    (void)rest;
    if (argc < 2)
        kprintf("Usage : rm <fichier>\n");
    for (int i = 1; i < argc; i++)
        if (fs_remove(argv[i]) < 0)
            error("Fichier introuvable : %s\n", argv[i]);
}

/* Calculatrice : descente récursive sur + - * / % et parenthèses. */
static const char *calc_pos;
static const char *calc_err;

static int32_t calc_expr(void);

static void calc_skip(void)
{
    while (*calc_pos == ' ')
        calc_pos++;
}

static int32_t calc_factor(void)
{
    calc_skip();
    if (*calc_pos == '-') {
        calc_pos++;
        return -calc_factor();
    }
    if (*calc_pos == '+') {
        calc_pos++;
        return calc_factor();
    }
    if (*calc_pos == '(') {
        calc_pos++;
        int32_t v = calc_expr();
        calc_skip();
        if (*calc_pos != ')') {
            calc_err = "parenthèse fermante manquante";
            return 0;
        }
        calc_pos++;
        return v;
    }
    if (!isdigit(*calc_pos)) {
        calc_err = "nombre attendu";
        return 0;
    }
    int32_t v = 0;
    if (calc_pos[0] == '0' && (calc_pos[1] == 'x' || calc_pos[1] == 'X')) {
        calc_pos += 2;
        for (;;) {
            char c = *calc_pos;
            int d = isdigit(c) ? c - '0' : (c >= 'a' && c <= 'f') ? c - 'a' + 10
                  : (c >= 'A' && c <= 'F') ? c - 'A' + 10 : -1;
            if (d < 0)
                break;
            v = v * 16 + d;
            calc_pos++;
        }
    } else {
        while (isdigit(*calc_pos))
            v = v * 10 + (*calc_pos++ - '0');
    }
    return v;
}

static int32_t calc_term(void)
{
    int32_t v = calc_factor();
    for (;;) {
        calc_skip();
        char op = *calc_pos;
        if (op != '*' && op != '/' && op != '%')
            return v;
        calc_pos++;
        int32_t r = calc_factor();
        if (op == '*') {
            v *= r;
        } else if (r == 0) {
            calc_err = "division par zéro";
            return 0;
        } else {
            v = op == '/' ? v / r : v % r;
        }
    }
}

static int32_t calc_expr(void)
{
    int32_t v = calc_term();
    for (;;) {
        calc_skip();
        char op = *calc_pos;
        if (op != '+' && op != '-')
            return v;
        calc_pos++;
        int32_t r = calc_term();
        v = op == '+' ? v + r : v - r;
    }
}

static void cmd_calc(int argc, char **argv, const char *rest)
{
    (void)argv;
    if (argc < 2) {
        kprintf("Usage : calc <expression>   ex. calc (2+3)*7 - 0x10\n");
        return;
    }
    calc_pos = rest;
    calc_err = NULL;
    int32_t v = calc_expr();
    calc_skip();
    if (!calc_err && *calc_pos)
        calc_err = "caractère inattendu";
    if (calc_err)
        error("Erreur : %s\n", calc_err);
    else
        kprintf("= %d  (0x%x)\n", v, (uint32_t)v);
}

static void cmd_snake(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    snake_run();
}

static void cmd_history(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    int first = history_count > HISTORY_SIZE ? history_count - HISTORY_SIZE : 0;
    for (int i = first; i < history_count; i++)
        kprintf("  %3d  %s\n", i + 1, history[i % HISTORY_SIZE]);
}

static void cmd_reboot(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    kprintf("Redémarrage...\n");
    sleep_ms(300);
    reboot();
}

static void cmd_halt(int argc, char **argv, const char *rest)
{
    (void)argc, (void)argv, (void)rest;
    kprintf("Arrêt du système...\n");
    sleep_ms(300);
    poweroff();
}

static const struct command commands[] = {
    { "help",    "",                   "affiche cette aide",                 cmd_help },
    { "about",   "",                   "informations sur le système",        cmd_about },
    { "clear",   "",                   "efface l'écran",                     cmd_clear },
    { "echo",    "<texte>",            "affiche un texte",                   cmd_echo },
    { "ls",      "",                   "liste les fichiers",                 cmd_ls },
    { "cat",     "<fichier>",          "affiche un fichier",                 cmd_cat },
    { "write",   "<fichier> <texte>",  "écrit (remplace) un fichier",        cmd_write },
    { "append",  "<fichier> <texte>",  "ajoute une ligne à un fichier",      cmd_append },
    { "rm",      "<fichier>",          "supprime un fichier",                cmd_rm },
    { "calc",    "<expression>",       "calculatrice entière",               cmd_calc },
    { "date",    "",                   "date et heure",                      cmd_date },
    { "uptime",  "",                   "temps depuis le démarrage",          cmd_uptime },
    { "mem",     "",                   "informations mémoire",               cmd_mem },
    { "color",   "<texte> [fond]",     "change les couleurs",                cmd_color },
    { "layout",  "[azerty|qwerty]",    "disposition du clavier",             cmd_layout },
    { "history", "",                   "dernières commandes",                cmd_history },
    { "snake",   "",                   "jeu du serpent",                     cmd_snake },
    { "reboot",  "",                   "redémarre la machine",               cmd_reboot },
    { "halt",    "",                   "éteint la machine",                  cmd_halt },
    { NULL, NULL, NULL, NULL },
};

static void execute(char *line)
{
    char raw[LINE_MAX];
    char *argv[MAX_ARGS];

    strlcpy(raw, line, sizeof(raw));
    int argc = parse_args(line, argv);
    if (!argc)
        return;

    if (!strcmp(argv[0], "aide"))
        argv[0] = "help";
    for (const struct command *c = commands; c->name; c++) {
        if (!strcmp(c->name, argv[0])) {
            c->run(argc, argv, skip_words(raw, 1));
            return;
        }
    }
    error("Commande inconnue : %s (tapez 'help')\n", argv[0]);
}

void shell_run(void)
{
    char line[LINE_MAX];

    for (;;) {
        prompt();
        readline(line);

        bool blank = true;
        for (char *p = line; *p; p++)
            if (*p != ' ')
                blank = false;
        if (blank)
            continue;

        if (!history_count || strcmp(history[(history_count - 1) % HISTORY_SIZE], line))
            strlcpy(history[history_count++ % HISTORY_SIZE], line, LINE_MAX);
        execute(line);
    }
}
