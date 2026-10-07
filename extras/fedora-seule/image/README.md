# Ton propre ISO installable (optionnel)

Au lieu de lancer `install.sh` sur une Fedora déjà installée, tu peux fabriquer **ton propre
système installable** : une Fedora Atomic (KDE Plasma) avec tout Windora dedans,
sur une clé USB, que tu installes sur n'importe quel PC.

C'est la méthode « moderne » de Fedora (images *bootc*), celle qu'utilise Bazzite.
Le système est **atomique** : les mises à jour s'appliquent d'un bloc et on peut revenir
à la version précédente au démarrage si quelque chose casse.

> ⚠️ Je n'ai pas pu construire cette image dans mon environnement (pas d'accès aux serveurs
> de Fedora) : le script d'installation qu'elle utilise est testé, mais la construction
> elle-même ne l'est pas. Signale-moi toute erreur.

## Fabriquer l'ISO

Depuis une Fedora (n'importe laquelle, avec ~30 Go libres) :

```sh
sudo dnf install podman
cd OS-Windora/extras/fedora-seule
./image/build-iso.sh
```

Résultat : `output/bootiso/install.iso`. Copie-la sur une clé USB avec
**Fedora Media Writer** (ou `dd`), démarre le PC dessus et installe.

Au premier démarrage, Heroic, Bottles, ProtonPlus et Flatseal s'installent tout seuls
depuis Flathub (il faut Internet).

## Limites

- **NVIDIA** : le pilote propriétaire n'est pas inclus (il doit être compilé pour le noyau
  exact de l'image, ce qui demande une chaîne de construction dédiée). Pour une carte
  NVIDIA, utilise plutôt **Bazzite** (image `bazzite-nvidia`) ou la méthode `install.sh`.
- **Mises à jour** : une image construite en local ne se met pas à jour toute seule. Pour
  cela, il faut la publier dans un registre (par exemple ghcr.io avec GitHub Actions, comme
  le modèle [ublue-os/image-template](https://github.com/ublue-os/image-template)), puis
  `sudo bootc switch ghcr.io/<toi>/<image>:latest`.

## Le nom

Pour un usage personnel, appelle-la comme tu veux. Mais si tu **publies** l'ISO :
« Fedora » et « Windows » sont des marques déposées (Red Hat et Microsoft) et ne peuvent pas
faire partie du nom d'un système distribué. Choisis un nom à toi. Tu peux écrire
« *TonNom*, a Fedora Remix » seulement si tu remplaces les logos Fedora (paquets
`fedora-logos`, `fedora-release`…) par les tiens, avec un lien vers fedoraproject.org.
Dire « compatible avec les jeux Windows » est autorisé.

## Déjà tout fait : Bazzite

[Bazzite](https://bazzite.gg) est exactement ce type d'image, maintenue par une équipe
(Fedora Kinoite/Silverblue + Steam + Proton + pilotes NVIDIA intégrés). Si tu veux le
résultat sans le construire toi-même, c'est la meilleure option.
