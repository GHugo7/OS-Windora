# NovaOS

Un petit système d'exploitation **32 bits x86** fait maison, écrit en C et en assembleur.
Il démarre directement sur la machine (sans Linux ni Windows en dessous) et propose un shell en français.

## Fonctionnalités

- Démarrage **multiboot** (GRUB ou `qemu -kernel`)
- GDT, IDT, PIC remappé, gestion des exceptions CPU (écran d'erreur fatale)
- Horloge système (PIT 100 Hz) et lecture de la date (RTC)
- Console texte VGA 80×25 en couleurs, avec les **accents** (UTF-8 converti en page de code 437)
- Clavier PS/2 **AZERTY** (AltGr, touches mortes `^` et `¨`) ou QWERTY
- Port série COM1 : l'OS peut être piloté depuis un terminal
- Shell : historique (↑/↓), complétion (Tab), guillemets, Ctrl+C, Ctrl+L
- Système de fichiers en mémoire (`ls`, `cat`, `write`, `append`, `rm`)
- Calculatrice (`calc (2+3)*7 - 0x10`) et jeu **Snake**

## Commandes

| Commande | Rôle |
|---|---|
| `help` / `aide` | liste des commandes |
| `about` | logo et infos système |
| `ls`, `cat`, `write`, `append`, `rm` | fichiers |
| `calc <expr>` | calculatrice entière |
| `date`, `uptime`, `mem` | heure, temps allumé, mémoire |
| `color <texte> [fond]` | couleurs (`color jaune bleu`, `color 10`) |
| `layout azerty\|qwerty` | disposition du clavier |
| `snake` | jeu du serpent (flèches ou ZQSD, P pause, Échap quitter) |
| `reboot`, `halt` | redémarrer / éteindre |

## Compiler et lancer

Sous Linux (ou WSL sous Windows) :

```sh
sudo apt install build-essential qemu-system-x86     # gcc avec support -m32
cd os
make run           # ouvre une fenêtre QEMU avec NovaOS
make run-serial    # sans fenêtre, directement dans le terminal
```

Pour une image ISO bootable (clé USB, VirtualBox) :

```sh
sudo apt install grub-pc-bin xorriso
make iso           # crée build/novaos.iso
make run-iso
```

> Pour une vraie machine, il faut un PC capable de démarrer en mode BIOS/Legacy (CSM).

## Organisation du code

| Fichier | Contenu |
|---|---|
| `src/boot.S` | en-tête multiboot, pile, chargement GDT/IDT |
| `src/interrupts.S` | points d'entrée des interruptions |
| `src/kernel.c` | `kmain`, redémarrage, extinction |
| `src/cpu.c` | GDT, IDT, PIC, exceptions |
| `src/timer.c` | PIT et RTC |
| `src/console.c` | écran VGA, port série, UTF-8 |
| `src/keyboard.c` | clavier PS/2 et entrée série |
| `src/fs.c` | système de fichiers en mémoire |
| `src/shell.c` | shell et commandes |
| `src/snake.c` | jeu Snake |
| `src/lib.c` | mini libc (chaînes, `kprintf`) |

Pour changer le nom de l'OS, modifiez `OS_NAME` dans `src/kernel.h`.

## Idées pour la suite

Allocation mémoire dynamique, pagination, pilote de disque (ATA) et vrai système de fichiers,
mode graphique, multitâche, programmes en mode utilisateur.
