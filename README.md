# Windora

**Fedora et Windows sur le même PC, sans choisir.**

Le noyau est celui de Windows : tous les `.exe`, tous les jeux, et **Vanguard** (Valorant,
League of Legends) fonctionnent normalement. Par-dessus, Windora intègre la **vraie Fedora
officielle** (via WSL, le sous-système Linux de Microsoft) :

- le **Terminal Windows s'ouvre directement sur Fedora** : `sudo dnf install`, `sudo dnf upgrade`,
  `rpm`, `systemctl`, `git`, `gcc`… toutes les commandes Fedora, sans rien lancer avant ;
- dans **PowerShell** aussi : `sudo dnf …`, `ls`, `cat`, `rm`, `htop`, `nano`… tapés au clavier
  vont dans Fedora (les scripts PowerShell, eux, gardent les commandes Windows) ;
- les **applications Linux** (Fichiers, éditeur de texte, GIMP…) apparaissent dans le
  **menu Démarrer**, dans un dossier « Fedora » ;
- **`installer`** installe des logiciels **Fedora et Windows dans la même commande** ;
- **double-clic sur un `.rpm`** : installé dans Fedora (après confirmation). Double-clic sur un
  `.exe` : Windows ;
- Windows est **allégé** (applis inutiles, télémétrie, pubs) et **habillé façon GNOME**.

## Installation

Sur **Windows 11** (Windows 10 22H2 fonctionne, mais n'est plus maintenu) :

1. Télécharge Windora : bouton **Code > Download ZIP** sur GitHub, puis décompresse-le.
2. Dans le dossier obtenu, **double-clique sur `installer.cmd`**.
   - Si Windows affiche « Windows a protégé votre ordinateur » : *Informations
     complémentaires > Exécuter quand même* (le script n'est pas signé).
3. Accepte la demande d'autorisation administrateur (installation de WSL et des applications).
4. Si WSL n'était pas installé, le PC redémarre une fois : **l'installation reprend toute
   seule** à l'ouverture de session.
5. Choisis ton nom d'utilisateur Linux (proposé d'après ton nom Windows).

Compte 10 à 20 minutes. À la fin, ouvre le **Terminal** : tu es dans Fedora.

Options (à ajouter après `installer.cmd` ou `setup.ps1`) :

| Option | Effet |
|---|---|
| `-Check` | vérifie seulement si le PC est prêt (Vanguard, WSL), sans rien changer |
| `-NoSlim` | n'allège pas Windows |
| `-NoLook` | ne change pas l'apparence |
| `-NoGuiApps` | pas d'applications graphiques Linux |
| `-NoDev` | pas de compilateur Windows (MinGW) dans Fedora |
| `-NoSteam` | n'installe pas Steam |
| `-UserName hugo` | nom du compte Linux |
| `-Yes` | aucune question |
| `-Restore` | annule l'habillage, l'allègement et l'intégration |

## Au quotidien

```sh
sudo dnf install gimp vlc        # logiciels Linux (ils arrivent dans le menu Démarrer)
sudo dnf upgrade                 # met Fedora à jour (Windows Update s'occupe de Windows)
installer firefox jeu-setup.exe  # Fedora ET Windows dans la même commande
installer --windows Discord      # logiciel Windows via winget
./setup.exe                      # lance un programme Windows depuis Fedora
open .                           # ouvre le dossier courant dans l'Explorateur
winget upgrade --all             # met à jour les logiciels Windows, depuis Fedora
```

**Compiler un programme Windows** dans Fedora et le lancer aussitôt (il tourne en natif
sur Windows) :

```sh
x86_64-w64-mingw32-gcc bonjour.c -o bonjour.exe && ./bonjour.exe
```

**Fichiers** : tes fichiers Windows sont dans `/mnt/c/Users/<toi>/` côté Fedora. Les fichiers
de Fedora sont visibles dans l'Explorateur, rubrique **Linux > Fedora**
(`\\wsl.localhost\Fedora`).

### Dans PowerShell

| Tu tapes | Ce qui se passe |
|---|---|
| `sudo dnf install htop`, `dnf search vlc` | Fedora |
| `ls`, `cat`, `cp`, `mv`, `rm`, `ps`, `kill`, `sort`, `diff`, `man`, `curl` | Fedora, dans le dossier courant |
| `htop`, `nano`, `git`… (inconnues de Windows) | Fedora |
| `Get-ChildItem`, `Get-Process`… | Windows (PowerShell) |
| un script `.ps1` qui utilise `ls` ou `rm` | Windows : les scripts ne changent pas de comportement |

Comme dans bash, `ls *.txt` développe le joker et `ls '*.txt'` (entre guillemets) ne le fait
pas ; `~` est ton dossier Fedora. Dans un PowerShell **administrateur**, ou hors d'un disque
local (registre, partage réseau), les commandes restent celles de Windows.

Attention : `rm -rf` est donc le vrai `rm` de Linux, sans corbeille. `ps` et `kill` agissent
sur les programmes de Fedora. Pour ceux de Windows : `Get-Process`, `Stop-Process`, ou le
Gestionnaire des tâches.

## Les jeux, Valorant et League of Legends

Windows est intact : Steam, Epic, Riot, Battle.net, EA, Xbox… s'installent et marchent comme
d'habitude. Le script vérifie que le PC est prêt pour **Vanguard** :

| Exigence | Où l'activer |
|---|---|
| Secure Boot | BIOS/UEFI > Boot > Secure Boot |
| TPM 2.0 | BIOS/UEFI : fTPM (AMD) ou PTT (Intel) |
| Intégrité de la mémoire (HVCI) | Sécurité Windows > Sécurité de l'appareil > Isolation du noyau |
| Virtualisation (pour WSL) | BIOS/UEFI : SVM (AMD) ou VT-x (Intel) |

**WSL et Vanguard** : Riot n'a rien publié sur WSL. WSL utilise le même hyperviseur Windows que
l'isolation du noyau, que Vanguard exige justement : ils cohabitent donc normalement. Si un jeu
affiche une erreur VAN, utilise l'outil « Vanguard Pre-Check » de Riot. **Ne désactive jamais
Hyper-V ou l'isolation du noyau** sur la foi d'un tuto : c'est ce qui provoque les erreurs
Vanguard aujourd'hui.

## Ce que fait l'allègement

Seulement des changements sans risque, tous annulables avec `-Restore`
(liste complète dans [`allegement.psd1`](allegement.psd1)) :

- **Applis retirées** : Actualités, Météo, Solitaire, To Do, Clipchamp, Power Automate, Hub de
  commentaires, Microsoft 365 (raccourci), Copilot, Astuces, Contacts, Cortana, recherche Bing.
  Elles se réinstallent depuis le Microsoft Store si besoin.
- **Fini les pubs** : suggestions et applis installées en douce, recommandations du menu
  Démarrer, résultats web dans la recherche, widgets, pubs OneDrive, demandes d'avis.
- **Moins de collecte** : télémétrie au minimum, tâches de collecte coupées, Recall désactivé.
- **Services** : télémétrie (`DiagTrack`) coupée, cartes hors ligne à la demande.
- **Edge** ne reste plus en mémoire quand il est fermé.
- **Jeux** : plus d'enregistrement vidéo en continu en arrière-plan.
- **Fedora** ne prend jamais plus d'un quart de la RAM, rend la mémoire inutilisée à Windows et
  **s'éteint toute seule** environ une minute après la dernière fenêtre Linux fermée : elle ne
  coûte rien quand tu joues. À l'intérieur, les services inutiles sous WSL (réseau, heure,
  Bluetooth, déjà gérés par Windows) sont coupés.

**Volontairement pas touché** : Windows Update, Defender, le pare-feu, Hyper-V et l'isolation
du noyau (Vanguard, WSL), Xbox / Game Pass / Game Bar, l'imprimante, le Bluetooth, la
localisation, l'indexation. Couper ces services au hasard (comme le font certains « débloat »)
casse les mises à jour, les jeux en ligne ou WSL pour un gain de mémoire nul : un service
arrêté ne consomme rien.

## Annuler

```powershell
.\setup.ps1 -Restore
```

Remet le thème, le fond d'écran, les réglages, les services, les tâches, le Terminal et
PowerShell comme avant. Fedora et tes fichiers Linux sont conservés. Pour supprimer Fedora
définitivement : `wsl --unregister Fedora`.

## Pourquoi pas « un Fedora avec le noyau Windows » ?

C'est exactement ce que fait Windora, sous la seule forme possible :

- le noyau Windows est fermé : sa licence interdit de le modifier ou de l'intégrer à un autre
  système, donc personne ne peut fabriquer une distribution Fedora avec ce noyau ;
- WSL fait le chemin inverse, officiellement : il fait tourner la **vraie Fedora** (image publiée
  par le projet Fedora) dans Windows. Le noyau reste celui de Windows, donc **Vanguard
  fonctionne** ;
- faire croire à Vanguard qu'un autre système est Windows (noyau « compatible », machine
  virtuelle cachée…) serait un contournement d'anti-triche : bannissement du compte et du
  matériel. Windora ne le fait pas.

## Limites honnêtes

- Le bureau reste celui de Windows (habillé façon GNOME) : WSL fait tourner les **applications**
  Linux, pas un bureau GNOME complet.
- Ce qui touche au matériel et au démarrage (noyau Linux, GRUB, Wi-Fi, veille) est géré par
  Windows : ces commandes Fedora n'ont pas d'effet.
- Le projet n'a pas pu être exécuté sur un vrai Windows pendant sa création : il a été vérifié
  par analyse (compatibilité PowerShell 5.1), par des tests de chaque fonction et par
  relecture. Signale tout problème dans les *Issues* du dépôt.

## Extras

Le dossier [`extras/`](extras) contient deux projets annexes, indépendants de Windora :

| Dossier | Contenu |
|---|---|
| [`extras/fedora-seule/`](extras/fedora-seule/README.md) | l'approche inverse : une Fedora **sans Windows** qui lance les `.exe` (Proton, Wine, Steam), avec la commande `fxw` et de quoi fabriquer son propre ISO. Pas de Valorant ni de LoL (Vanguard ne tourne pas sous Linux). |
| [`extras/novaos/`](extras/novaos/README.md) | NovaOS, un petit système d'exploitation écrit de zéro (noyau x86 en C), pour comprendre comment marche un OS. |

## Organisation des fichiers

| Fichier | Rôle |
|---|---|
| `installer.cmd` | à double-cliquer : lance l'installation |
| `setup.ps1` | le script d'installation (Windows PowerShell) |
| `allegement.psd1` | la liste de l'allègement de Windows |
| `fxw-profile.ps1` | les commandes Fedora dans PowerShell |
| `fedora/` | ce qui est installé dans Fedora : `installer`, `fxw-exec`, configuration, allègement |
| `assets/` | le fond d'écran |

## Mentions

Projet personnel, non affilié à Microsoft, Red Hat, au projet Fedora ni à Riot Games.
Fedora est une marque de Red Hat, Inc. Windows est une marque de Microsoft Corporation.
Les polices Adwaita (GNOME) sont téléchargées depuis leur dépôt officiel (licence OFL).
