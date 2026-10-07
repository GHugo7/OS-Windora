/* Système de fichiers en mémoire (RAMFS) : plat, sans dossiers, perdu à l'extinction. */
#include "kernel.h"

static struct file files[FS_MAX_FILES];

struct file *fs_find(const char *name)
{
    for (int i = 0; i < FS_MAX_FILES; i++)
        if (files[i].used && !strcmp(files[i].name, name))
            return &files[i];
    return NULL;
}

struct file *fs_at(int index)
{
    if (index < 0 || index >= FS_MAX_FILES || !files[index].used)
        return NULL;
    return &files[index];
}

/* Renvoie le nombre d'octets écrits, ou -1 (nom invalide / plus de place). */
int fs_write(const char *name, const char *data, uint32_t len, bool append)
{
    size_t name_len = strlen(name);
    if (!name_len || name_len >= FS_NAME_MAX)
        return -1;

    struct file *f = fs_find(name);
    if (!f) {
        for (int i = 0; i < FS_MAX_FILES && !f; i++)
            if (!files[i].used)
                f = &files[i];
        if (!f)
            return -1;
        f->used = true;
        strlcpy(f->name, name, FS_NAME_MAX);
        f->size = 0;
    }
    if (!append)
        f->size = 0;
    if (len > FS_FILE_MAX - f->size)
        len = FS_FILE_MAX - f->size;
    memcpy(f->data + f->size, data, len);
    f->size += len;
    return (int)len;
}

int fs_remove(const char *name)
{
    struct file *f = fs_find(name);
    if (!f)
        return -1;
    f->used = false;
    return 0;
}

static void fs_create(const char *name, const char *text)
{
    fs_write(name, text, strlen(text), false);
}

void fs_init(void)
{
    fs_create("lisezmoi.txt",
              "Bienvenue dans " OS_NAME " !\n"
              "\n"
              "C'est un petit système d'exploitation 32 bits écrit en C,\n"
              "qui démarre directement sur un PC (ou dans QEMU).\n"
              "\n"
              "Tapez 'help' pour voir les commandes.\n"
              "Les fichiers vivent en mémoire : ils disparaissent au redémarrage.\n");
    fs_create("idees.txt",
              "- un vrai système de fichiers sur disque\n"
              "- le mode graphique\n"
              "- le multitâche\n");
}
